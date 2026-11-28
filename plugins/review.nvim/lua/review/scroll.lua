-- Keeps the screen still while deleted lines appear and disappear with edits.
local M = {}

local function saved_view(winid)
    return vim.api.nvim_win_call(winid, vim.fn.winsaveview)
end

local function restore_view(winid, view)
    vim.api.nvim_win_call(winid, function()
        vim.fn.winrestview(view)
    end)
end

-- Screen rows of the lines. With start_vcol, from the first line's text, so without the virtual lines above it.
local function screen_rows(winid, first_line, last_line, start_vcol)
    return vim.api.nvim_win_text_height(winid, { start_row = first_line - 1, end_row = last_line - 1, start_vcol = start_vcol }).all
end

-- Without the winbar.
local function text_rows(winid)
    return vim.fn.winheight(winid)
end

local function virtual_lines_above(winid, line)
    return screen_rows(winid, line, line) - screen_rows(winid, line, line, 0)
end

-- Screen rows from the window's top to the line's text. Negative above the window.
local function row_of(winid, line)
    local view = saved_view(winid)
    if line < view.topline then
        return -screen_rows(winid, line, view.topline - 1, 0)
    end
    -- topfill is stale until the redraw when virtual lines above the top line go away.
    local hidden = math.max(virtual_lines_above(winid, view.topline) - view.topfill, 0)
    return screen_rows(winid, view.topline, line) - screen_rows(winid, line, line, 0) - hidden
end

-- Scrolls so the line's text is the given screen rows from the top.
local function scroll_to(winid, line, rows)
    while true do
        local above = virtual_lines_above(winid, line)
        if rows <= above or line == 1 then
            return restore_view(winid, { topline = line, topfill = math.min(rows, above) })
        end
        line = line - 1
        rows = rows - above - screen_rows(winid, line, line, 0)
        -- Within a wrapped line, the line ends up a little lower.
        if rows <= 0 then
            return restore_view(winid, { topline = line, topfill = 0 })
        end
    end
end

-- By window, where the cursor line was on screen when last rendered, and the lines then. Measured after an edit,
-- the stale virtual lines have already moved.
local settled = {}

-- Called once the screen shows the window rendered for the lines.
function M.settle(winid, lines)
    local cursor_line, view = vim.api.nvim_win_get_cursor(winid)[1], saved_view(winid)
    settled[winid] = {
        lines = lines,
        cursor_line = cursor_line,
        cursor_row = row_of(winid, cursor_line),
        topline = view.topline,
        topfill = view.topfill,
        top_virtual_lines = virtual_lines_above(winid, view.topline),
    }
end

-- How many lines at the start and end the edit left unchanged.
local function unchanged_ends(old_lines, new_lines)
    local at_start, at_end = 0, 0
    while at_start < #old_lines and old_lines[at_start + 1] == new_lines[at_start + 1] do
        at_start = at_start + 1
    end
    while at_end < math.min(#old_lines, #new_lines) and old_lines[#old_lines - at_end] == new_lines[#new_lines - at_end] do
        at_end = at_end + 1
    end
    return at_start, at_end
end

-- An edit within the cursor line, like typing, keeps that line on its row. An edit adding or deleting lines keeps
-- the screen still instead, as scrolling then is jarring.
function M.keep(bufnr, old_lines, new_lines)
    local unchanged_start, unchanged_end = unchanged_ends(old_lines, new_lines)
    for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
        local last = settled[winid]
        -- Only when last settled with these lines.
        if last and last.lines == old_lines then
            local line, cursor_line, line_delta = last.cursor_line, vim.api.nvim_win_get_cursor(winid)[1], #new_lines - #old_lines
            local edited_in_place = line_delta == 0 and unchanged_start >= line - 1 and unchanged_end >= #old_lines - line
            if edited_in_place then
                -- Left to Vim when it was off screen.
                local on_screen = last.cursor_row >= 0 and last.cursor_row < text_rows(winid)
                if on_screen and row_of(winid, line) ~= last.cursor_row then
                    scroll_to(winid, line, last.cursor_row)
                end
            else
                -- Shows deleted lines that appeared above the top line, and hides them when they go.
                local view = saved_view(winid)
                local top_virtual_lines = virtual_lines_above(winid, view.topline)
                if view.topline == last.topline and top_virtual_lines ~= last.top_virtual_lines then
                    local topfill = last.topfill + top_virtual_lines - last.top_virtual_lines
                    restore_view(winid, { topline = view.topline, topfill = math.max(math.min(topfill, top_virtual_lines), 0) })
                end
                -- Deleting upwards, like `dk`, leaves the cursor above the deleted lines.
                local lines_removed = -line_delta
                local deleted_upwards = (last.visual_start or line) == cursor_line + lines_removed - 1
                if lines_removed > 1 and deleted_upwards and cursor_line > 1 then
                    local text = vim.api.nvim_buf_get_lines(bufnr, cursor_line - 2, cursor_line - 1, true)[1]
                    vim.api.nvim_win_set_cursor(winid, { cursor_line - 1, #text:match("^%s*") })
                end
                -- Keeps the cursor on screen when deleted lines above push it below, like holding dd on the last row.
                cursor_line = vim.api.nvim_win_get_cursor(winid)[1]
                local cursor_rows, window_rows = screen_rows(winid, cursor_line, cursor_line, 0), text_rows(winid)
                local was_on_screen = last.cursor_row >= 0 and last.cursor_row < window_rows
                if was_on_screen and row_of(winid, cursor_line) + cursor_rows > window_rows then
                    scroll_to(winid, cursor_line, window_rows - cursor_rows)
                end
            end
        end
        M.settle(winid, new_lines)
    end
end

-- Before each key in visual mode, records where the selection started, to tell later which way it deleted.
function M.key()
    local last = settled[vim.api.nvim_get_current_win()]
    if last and vim.api.nvim_get_mode().mode:match("^[vV\22]") then
        last.visual_start = vim.fn.line("v")
    end
end

-- Shows deleted lines above the first line when the buffer opens at the top.
function M.reveal(bufnr)
    for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
        local view = saved_view(winid)
        if view.topline == 1 and view.topfill == 0 then
            restore_view(winid, { topline = 1, topfill = virtual_lines_above(winid, 1) })
        end
    end
end

return M
