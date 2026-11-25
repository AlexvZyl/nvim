-- Keeps the screen in place while the deleted lines drawn above and below the lines come and go with the edits.
local M = {}

local function view(win)
    return vim.api.nvim_win_call(win, vim.fn.winsaveview)
end

local function restore(win, saved)
    vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(saved)
    end)
end

-- Screen rows of the lines, starting at the text of the first one when vcol is given.
local function height(win, first, last, vcol)
    return vim.api.nvim_win_text_height(win, { start_row = first - 1, end_row = last - 1, start_vcol = vcol }).all
end

-- Rows of text in the window, without the winbar the window's height counts.
local function text_rows(win)
    return vim.fn.winheight(win)
end

-- Virtual lines above the line.
local function fill(win, line)
    return height(win, line, line) - height(win, line, line, 0)
end

-- Screen rows between the top of the window and the line's text, negative above the window.
local function line_row(win, line)
    local top = view(win)
    if line < top.topline then
        return -height(win, line, top.topline - 1, 0)
    end
    -- topfill is stale until the next redraw when the virtual lines above the top line go away.
    local hidden = math.max(fill(win, top.topline) - top.topfill, 0)
    return height(win, top.topline, line) - height(win, line, line, 0) - hidden
end

-- Scrolls so the line's text is the given number of screen rows below the top of the window.
local function scroll_to(win, line, rows)
    while true do
        local above = fill(win, line)
        if rows <= above or line == 1 then
            return restore(win, { topline = line, topfill = math.min(rows, above) })
        end
        line = line - 1
        rows = rows - above - height(win, line, line, 0)
        -- Short of the whole of a wrapped line, the line ends up a little lower.
        if rows <= 0 then
            return restore(win, { topline = line, topfill = 0 })
        end
    end
end

-- By window, the screen row of the cursor line as last seen with the hunks rendered, and the lines they were rendered
-- for. Measured once an edit is made, the stale virtual lines have already moved.
local settled = {}

-- Once the screen shows the window's buffer rendered for the lines, so cursor moves and scrolls are kept by the next
-- render.
function M.settle(win, lines)
    local line, top = vim.api.nvim_win_get_cursor(win)[1], view(win)
    settled[win] = {
        lines = lines,
        line = line,
        row = line_row(win, line),
        topline = top.topline,
        topfill = top.topfill,
        fill = fill(win, top.topline),
    }
end

-- How many lines at the start and at the end the edit from the old lines to the new ones left as they were.
local function unchanged(old, new)
    local before, after = 0, 0
    while before < #old and old[before + 1] == new[before + 1] do
        before = before + 1
    end
    while after < math.min(#old, #new) and old[#old - after] == new[#new - after] do
        after = after + 1
    end
    return before, after
end

-- Through an edit within the line the cursor was on, like typing or commenting it, the line stays on its row, like
-- without the deleted line that comes or goes above it. Through an edit that adds or deletes lines, like deleting
-- it, scrolling is jarring, so the screen stays and the lines move instead.
function M.keep(buf, old, new)
    local before_lines, after_lines = unchanged(old, new)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        local before = settled[win]
        -- Not when last seen with other lines, like those of the file before it was read again.
        if before and before.lines == old then
            local line, cursor, added = before.line, vim.api.nvim_win_get_cursor(win)[1], #new - #old
            -- As many lines, as before above and below it.
            local within = added == 0 and before_lines >= line - 1 and after_lines >= #old - line
            if within then
                -- Off screen when it was, which is left to Vim.
                local shown = before.row >= 0 and before.row < text_rows(win)
                if shown and line_row(win, line) ~= before.row then
                    scroll_to(win, line, before.row)
                end
            else
                -- Shows the deleted lines that came above the top line, like when the lines at the top are deleted,
                -- and hides them again once they go, like when that is undone.
                local top = view(win)
                local above = fill(win, top.topline)
                if top.topline == before.topline and above ~= before.fill then
                    restore(win, { topline = top.topline, topfill = math.max(math.min(before.topfill + above - before.fill, above), 0) })
                end
                -- Deleting up, from the last of the deleted lines like `dk` or a selection up, goes on the line above
                -- them so the cursor stays at the top. Deleting down leaves it below them.
                local removed = -added
                if removed > 1 and (before.visual or line) == cursor + removed - 1 and cursor > 1 then
                    local text = vim.api.nvim_buf_get_lines(buf, cursor - 2, cursor - 1, true)[1]
                    vim.api.nvim_win_set_cursor(win, { cursor - 1, #text:match("^%s*") })
                end
                -- Kept on the bottom row once the deleted lines above push it below, like holding dd or . there. Left
                -- below the window, the screen scrolls only with the redraw, which draws the cursor above them.
                cursor = vim.api.nvim_win_get_cursor(win)[1]
                local rows, shown_rows = height(win, cursor, cursor, 0), text_rows(win)
                if before.row >= 0 and before.row < shown_rows and line_row(win, cursor) + rows > shown_rows then
                    scroll_to(win, cursor, shown_rows - rows)
                end
            end
        end
        M.settle(win, new)
    end
end

-- Before every key in visual mode, where the selection started, so once an operator deletes it whether it went
-- up or down is known. Once visual mode ends that is gone.
function M.key()
    local current = settled[vim.api.nvim_get_current_win()]
    if current and vim.api.nvim_get_mode().mode:match("^[vV\22]") then
        current.visual = vim.fn.line("v")
    end
end

-- Shows the deleted lines above the first line when the buffer is opened at the top, like for a deleted file.
function M.reveal(buf)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        local top = view(win)
        if top.topline == 1 and top.topfill == 0 then
            restore(win, { topline = 1, topfill = fill(win, 1) })
        end
    end
end

return M
