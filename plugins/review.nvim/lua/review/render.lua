local config = require("review.config")
local git = require("review.git")
local session = require("review.session")

local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local deleted_namespace = vim.api.nvim_create_namespace("review_deleted")
local anchor_namespace = vim.api.nvim_create_namespace("review_anchor")
local SIGN = "│"
-- Sets uncommitted changes apart from committed ones.
local LOCAL_SIGN = "╎"
-- Attached buffers, with the file at the merge base and the current hunks against it.
local buffers = {}

local function parse_hunks(patch)
    local hunks = {}
    local current
    for _, line in ipairs(vim.split(patch, "\n", { plain = true })) do
        local old, start, count = line:match("^@@ %-(%d+),?%d* %+(%d+),?(%d*) @@")
        if start then
            current = {
                old = tonumber(old),
                start = tonumber(start),
                -- A missing count means a single line.
                count = count == "" and 1 or tonumber(count),
                deleted = {},
            }
            table.insert(hunks, current)
        elseif current and line:sub(1, 1) == "-" then
            table.insert(current.deleted, line:sub(2))
        end
    end
    return hunks
end

-- Treesitter highlight of every byte of the deleted lines, by line.
local function highlight_deleted(lang, deleted)
    local highlights = {}
    local query = lang and vim.treesitter.query.get(lang, "highlights")
    if not query then
        return highlights
    end
    local source = table.concat(deleted, "\n")
    local ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
    if not ok then
        return highlights
    end
    for id, node in query:iter_captures(parser:parse()[1]:root(), source) do
        local name = query.captures[id]
        if not name:find("^_") and name ~= "spell" and name ~= "nospell" then
            local start_row, start_col, end_row, end_col = node:range()
            for row = start_row, math.min(end_row, #deleted - 1) do
                local line = highlights[row + 1] or {}
                highlights[row + 1] = line
                local last = row == end_row and end_col or #deleted[row + 1]
                for col = (row == start_row and start_col or 0) + 1, last do
                    line[col] = "@" .. name .. "." .. lang
                end
            end
        end
    end
    return highlights
end

-- Shared so neighbouring characters with the same highlight merge into one chunk.
local delete_groups = { [false] = {}, [true] = {} }

local function delete_group(name, uncommitted)
    local base = uncommitted and "ReviewLocalDelete" or "ReviewDelete"
    if not name then
        return base
    end
    local groups = delete_groups[uncommitted]
    groups[name] = groups[name] or { base, name }
    return groups[name]
end

-- Virtual text of a deleted line, scrolled by leftcol and padded to the edge like a line highlight.
local function deleted_chunks(text, highlights, uncommitted, leftcol, tabstop)
    local chunks, width = {}, 0
    local function add(char, group)
        width = width + 1
        if width <= leftcol then
            return
        end
        local last = chunks[#chunks]
        if last and last[2] == group then
            last[1] = last[1] .. char
        else
            table.insert(chunks, { char, group })
        end
    end
    local byte = 1
    -- A UTF-8 lead byte followed by its continuation bytes.
    for char in text:gmatch("[^\128-\191][\128-\191]*") do
        local group = delete_group(highlights[byte], uncommitted)
        byte = byte + #char
        if char == "\t" then
            for _ = 1, tabstop do
                add(" ", group)
            end
        else
            add(char, group)
        end
    end
    local pad = string.rep(" ", math.max(vim.o.columns - width + leftcol, 0))
    table.insert(chunks, { pad, uncommitted and "ReviewLocalDelete" or "ReviewDelete" })
    return chunks
end

local function window(buf)
    return vim.fn.win_findbuf(buf)[1] or vim.api.nvim_get_current_win()
end

-- Width of the gutter.
local function textoff(buf)
    return vim.fn.getwininfo(window(buf))[1].textoff
end

-- Drawn separately from the added lines, since they depend on the window's scroll and gutter.
local function render_deleted(buf)
    vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
    local win = window(buf)
    -- As last seen after a redraw. Right after an edit, before the redraw, a statuscolumn is not measured yet.
    local width = buffers[buf].textoff or textoff(buf)
    buffers[buf].textoff = width
    local leftcol = vim.api.nvim_win_call(win, vim.fn.winsaveview).leftcol
    local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    local tabstop = vim.bo[buf].tabstop
    local line_count = vim.api.nvim_buf_line_count(buf)
    -- Virtual lines have no number or sign column, so draw them in.
    local number = { " ", "LineNr" }
    local padding = string.rep(" ", width - 2)
    local signs = {
        [false] = { SIGN .. padding, "ReviewSignDelete" },
        [true] = { LOCAL_SIGN .. padding, "ReviewSignLocalDelete" },
    }
    local committed = buffers[buf].committed_deletions
    -- The deleted lines by where they go, each with where it was in HEAD to order them by.
    local anchors, rows = {}, {}
    -- Deleted by commits against the base, and everything deleted against HEAD as uncommitted.
    local function add(hunk, uncommitted)
        -- A pure deletion starts at the line before it, so goes above the line after it unless it is at the end.
        local row = hunk.count > 0 and hunk.start - 1 or hunk.start
        for i, text in ipairs(hunk.deleted) do
            local key = uncommitted and hunk.old + i - 1 or committed[hunk.old + i - 1]
            if key then
                hunk.highlights = hunk.highlights or highlight_deleted(lang, hunk.deleted)
                local chunks = deleted_chunks(text, hunk.highlights[i] or {}, uncommitted, leftcol, tabstop)
                if not anchors[row] then
                    anchors[row] = {}
                    table.insert(rows, row)
                end
                local lines = anchors[row]
                table.insert(lines, { key = key, order = #lines, chunks = vim.list_extend({ number, signs[uncommitted] }, chunks) })
            end
        end
    end
    for _, hunk in ipairs(buffers[buf].hunks) do
        add(hunk, false)
    end
    for _, hunk in ipairs(buffers[buf].local_hunks) do
        add(hunk, true)
    end
    for _, row in ipairs(rows) do
        local lines = anchors[row]
        table.sort(lines, function(a, b)
            return a.key == b.key and a.order < b.order or a.key < b.key
        end)
        local above = row < line_count
        -- Left gravity keeps lines inserted at the mark, like an undone delete, below the deleted lines.
        vim.api.nvim_buf_set_extmark(buf, deleted_namespace, above and row or line_count - 1, 0, {
            virt_lines = vim.tbl_map(function(line)
                return line.chunks
            end, lines),
            virt_lines_above = above,
            virt_lines_leftcol = true,
            right_gravity = false,
        })
    end
end

-- Screen rows of the lines, starting at the text of the first one when vcol is given.
local function height(win, first, last, vcol)
    return vim.api.nvim_win_text_height(win, { start_row = first - 1, end_row = last - 1, start_vcol = vcol }).all
end

-- Virtual lines above the line.
local function fill(win, line)
    return height(win, line, line) - height(win, line, line, 0)
end

-- Screen rows between the top of the window and the line's text, negative above the window.
local function line_row(win, line)
    local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    if line < view.topline then
        return -height(win, line, view.topline - 1, 0)
    end
    -- topfill is stale until the next redraw when the virtual lines above the top line go away.
    local hidden = math.max(fill(win, view.topline) - view.topfill, 0)
    return height(win, view.topline, line) - height(win, line, line, 0) - hidden
end

-- Scrolls so the line's text is the given number of screen rows below the top of the window.
local function scroll_to(win, line, rows)
    local view
    while not view do
        local above = fill(win, line)
        if rows <= above or line == 1 then
            view = { topline = line, topfill = math.min(rows, above) }
        else
            rows = rows - above
            line = line - 1
            local text = height(win, line, line, 0)
            -- Short of the whole of a wrapped line, the line ends up a little lower.
            if rows <= text then
                view = { topline = line, topfill = 0 }
            end
            rows = rows - text
        end
    end
    vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(view)
    end)
end

-- By window, the screen row of the cursor line as last seen with the hunks rendered, and a mark at its start
-- that moves with the edits. Measured once an edit is made, the stale virtual lines have already moved.
local settled_rows = {}

local function settle(win, buf)
    local line = vim.api.nvim_win_get_cursor(win)[1]
    -- Over the whole line with its line break, so it is only invalidated when the line is deleted.
    local last = line == vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_extmark(buf, anchor_namespace, line - 1, 0, {
        id = win,
        end_row = last and line - 1 or line,
        end_col = last and #vim.api.nvim_buf_get_lines(buf, line - 1, line, true)[1] or 0,
        invalidate = true,
        undo_restore = false,
    })
    local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    settled_rows[win] = {
        buf = buf,
        line = line,
        count = vim.api.nvim_buf_line_count(buf),
        row = line_row(win, line),
        topline = view.topline,
        topfill = view.topfill,
        fill = fill(win, view.topline),
    }
end

-- Shows the deleted lines that came above the top line, like when the lines at the top are deleted, and hides
-- them again once they go, like when that is undone.
local function show_top(win, settled)
    local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    local above = fill(win, view.topline)
    if view.topline == settled.topline and above ~= settled.fill then
        local topfill = math.max(math.min(settled.topfill + above - settled.fill, above), 0)
        vim.api.nvim_win_call(win, function()
            vim.fn.winrestview({ topline = view.topline, topfill = topfill })
        end)
    end
end

-- Scrolls so the line the cursor was on stays in place on screen when edited. The deleted lines added or removed
-- above it then do not move it, while the cursor still moves with the edit.
local function keep_cursor(buf, fn)
    fn()
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        local settled = settled_rows[win]
        local mark = settled
            and settled.buf == buf
            and vim.api.nvim_buf_get_extmark_by_id(buf, anchor_namespace, win, { details = true })
        -- Not found once invalidated.
        local deleted = mark and (not mark[1] or mark[3].invalid)
        -- Only when the edit was on or after the line. Otherwise nothing moves, like the deleted lines taking the
        -- place of the line with the cursor below them, or an undo putting lines back in place of deleted ones.
        if mark and not deleted and mark[1] + 1 == settled.line then
            local line = mark[1] + 1
            local row = line_row(win, line)
            -- Off screen when the mark was, which is left to Vim.
            if row ~= settled.row and settled.row >= 0 and settled.row < vim.api.nvim_win_get_height(win) then
                scroll_to(win, line, settled.row)
            end
        elseif mark then
            show_top(win, settled)
            -- Deleting up, from the last of the deleted lines like `dk` or a selection up, goes on the line above
            -- them so the cursor stays at the top. Deleting down leaves it below them.
            local cursor = vim.api.nvim_win_get_cursor(win)[1]
            local removed = settled.count - vim.api.nvim_buf_line_count(buf)
            local start = settled.visual or settled.line
            if deleted and removed > 1 and start == cursor + removed - 1 and cursor > 1 then
                local text = vim.api.nvim_buf_get_lines(buf, cursor - 2, cursor - 1, true)[1]
                vim.api.nvim_win_set_cursor(win, { cursor - 1, #text:match("^%s*") })
            end
        end
        settle(win, buf)
    end
end

local function render(buf)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    local uncommitted = {}
    for _, hunk in ipairs(buffers[buf].local_hunks) do
        for line = hunk.start, hunk.start + hunk.count - 1 do
            uncommitted[line] = true
            vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                line_hl_group = "ReviewLocalAdd",
                number_hl_group = "ReviewLocalAddNr",
                sign_text = LOCAL_SIGN,
                sign_hl_group = "ReviewSignLocalAdd",
                priority = config.options.sign_priority,
            })
        end
    end
    for _, hunk in ipairs(buffers[buf].hunks) do
        for line = hunk.start, hunk.start + hunk.count - 1 do
            if not uncommitted[line] then
                vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                    line_hl_group = "ReviewAdd",
                    number_hl_group = "ReviewAddNr",
                    sign_text = SIGN,
                    sign_hl_group = "ReviewSignAdd",
                    priority = config.options.sign_priority,
                })
            end
        end
    end
    render_deleted(buf)
end

local function jump(buf, forward)
    local current = vim.api.nvim_win_get_cursor(0)[1]
    local target
    for _, hunk in ipairs(buffers[buf] and buffers[buf].hunks or {}) do
        local line = math.max(hunk.start, 1)
        if forward and line > current then
            target = target or line
        elseif not forward and line < current then
            target = line
        end
    end
    if target then
        vim.api.nvim_win_set_cursor(0, { target, 0 })
    end
end

local function buffer_text(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines == 1 and lines[1] == "" then
        return ""
    end
    return table.concat(lines, "\n") .. "\n"
end

local function diff(from, to)
    return parse_hunks(vim.text.diff(from, to, { ctxlen = 0, indent_heuristic = true }) or "")
end

-- Diffs the buffer against the merge base in memory, so edits show up while typing.
function M.update(buf)
    local attached = buffers[buf]
    if not attached or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local text = buffer_text(buf)
    local hunks = diff(attached.base, text)
    -- Treesitter highlights of deleted lines only change when the deleted text does.
    local cached = {}
    for _, hunk in ipairs(vim.list_extend(vim.list_extend({}, attached.hunks), attached.local_hunks or {})) do
        cached[table.concat(hunk.deleted, "\n")] = hunk.highlights
    end
    local local_hunks = diff(attached.head, text)
    for _, hunk in ipairs(vim.list_extend(vim.list_extend({}, hunks), local_hunks)) do
        hunk.highlights = cached[table.concat(hunk.deleted, "\n")]
    end
    attached.hunks = hunks
    attached.local_hunks = local_hunks
    -- Right away, as TextChanged comes before the redraw: scheduled, the edit would show without the deleted
    -- lines for a moment.
    keep_cursor(buf, function()
        render(buf)
    end)
    attached.rendered = hunks
    -- The width of the gutter the deleted lines draw in is only right after the redraw.
    vim.schedule(function()
        if buffers[buf] == attached and attached.hunks == hunks and vim.api.nvim_buf_is_valid(buf) then
            local width = textoff(buf)
            if attached.textoff ~= width then
                attached.textoff = width
                render_deleted(buf)
            end
        end
    end)
end

-- Before every key in visual mode, where the selection started, so once an operator deletes it whether it went
-- up or down is known. Once visual mode ends that is gone.
function M.key()
    local settled = settled_rows[vim.api.nvim_get_current_win()]
    if settled and vim.api.nvim_get_mode().mode:match("^[vV\22]") then
        settled.visual = vim.fn.line("v")
    end
end

-- Once the screen shows the rendered hunks, so cursor moves and scrolls are kept by the next render.
function M.settled()
    local rows = settled_rows
    settled_rows = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local attached = buffers[buf]
        if attached and attached.rendered == attached.hunks then
            settle(win, buf)
        else
            settled_rows[win] = rows[win]
        end
    end
end

function M.attach(buf)
    local file = vim.api.nvim_buf_get_name(buf)
    -- Also when the file does not exist, to show a deleted file as all deleted lines.
    if vim.bo[buf].buftype ~= "" or file == "" or vim.fn.isdirectory(file) == 1 then
        return
    end
    local base = session.merge_base and git.show(session.merge_base, file)
    local head = git.show("HEAD", file)
    local binary = (base or ""):find("\0", 1, true) or (head or ""):find("\0", 1, true)
    if (not base and not head) or binary then
        -- Untracked, outside the repo or binary.
        return M.detach(buf)
    end
    if not buffers[buf] then
        buffers[buf] = { hunks = {} }
        local keys = config.options.keymaps
        if keys.next_hunk then
            vim.keymap.set("n", keys.next_hunk, function()
                jump(buf, true)
            end, { buffer = buf })
        end
        if keys.prev_hunk then
            vim.keymap.set("n", keys.prev_hunk, function()
                jump(buf, false)
            end, { buffer = buf })
        end
    end
    -- No base when the file was added since the merge base, no head when it was added since HEAD.
    local attached = buffers[buf]
    attached.base = base or ""
    attached.head = head or ""
    -- Lines of the base deleted by commits, other deleted lines are only deleted locally. With where they were
    -- between the lines of HEAD: after the line before them, or before the lines that replaced them.
    attached.committed_deletions = {}
    for _, hunk in ipairs(diff(attached.base, attached.head)) do
        local key = hunk.count == 0 and hunk.start + 0.5 or hunk.start - 0.5
        for i = 1, #hunk.deleted do
            attached.committed_deletions[hunk.old + i - 1] = key
        end
    end
    M.update(buf)
end

function M.detach(buf)
    if not buffers[buf] then
        return
    end
    buffers[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
        vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
        vim.api.nvim_buf_clear_namespace(buf, anchor_namespace, 0, -1)
        for _, key in ipairs({ config.options.keymaps.next_hunk, config.options.keymaps.prev_hunk }) do
            if key then
                pcall(vim.keymap.del, "n", key, { buffer = buf })
            end
        end
    end
end

function M.scrolled()
    for win, delta in pairs(vim.v.event) do
        local id = tonumber(win)
        if id and delta.leftcol ~= 0 and vim.api.nvim_win_is_valid(id) then
            local buf = vim.api.nvim_win_get_buf(id)
            if buffers[buf] then
                render_deleted(buf)
            end
        end
    end
end

local DELETED_PREFIX = "review://"

-- A read-only buffer with a deleted file as it was at the merge base, all marked deleted, so the cursor can go
-- through it.
local function fill_deleted(buf, path)
    local lines = vim.split(git.show(session.merge_base, path) or "", "\n", { plain = true })
    if lines[#lines] == "" and #lines > 1 then
        table.remove(lines)
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    -- Still in HEAD when only deleted locally.
    local uncommitted = git.show("HEAD", path) ~= nil
    for i = 1, #lines do
        vim.api.nvim_buf_set_extmark(buf, namespace, i - 1, 0, {
            line_hl_group = uncommitted and "ReviewLocalDelete" or "ReviewDelete",
            number_hl_group = uncommitted and "ReviewLocalDeleteNr" or "ReviewDeleteNr",
            sign_text = uncommitted and LOCAL_SIGN or SIGN,
            sign_hl_group = uncommitted and "ReviewSignLocalDelete" or "ReviewSignDelete",
            priority = config.options.sign_priority,
        })
    end
end

function M.deleted_buffer(path)
    local buf = vim.fn.bufadd(DELETED_PREFIX .. path)
    if vim.api.nvim_buf_is_loaded(buf) then
        return buf
    end
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.fn.bufload(buf)
    fill_deleted(buf, path)
    vim.bo[buf].filetype = vim.filetype.match({ filename = path, buf = buf }) or ""
    return buf
end

-- After git changed what is reviewed: buffers of files no longer deleted make way for the file, the others are
-- rebuilt when what they show moved.
function M.refresh_deleted(moved)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.startswith(vim.api.nvim_buf_get_name(buf), DELETED_PREFIX) then
            local path = M.path(buf)
            local file = session.by_key[session.prefix .. path]
            if not (file and file.deleted) then
                for _, win in ipairs(vim.fn.win_findbuf(buf)) do
                    vim.api.nvim_win_call(win, function()
                        vim.cmd.edit(vim.fn.fnameescape(path))
                    end)
                end
                vim.api.nvim_buf_delete(buf, { force = true })
            elseif moved then
                fill_deleted(buf, path)
            end
        end
    end
end

-- The path of a file from its buffer, also for a deleted file's.
function M.path(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    return vim.startswith(name, DELETED_PREFIX) and name:sub(#DELETED_PREFIX + 1) or vim.fn.fnamemodify(name, ":.")
end

-- Shows the deleted lines above the first line when the buffer is opened at the top, like for a deleted file.
function M.reveal(buf)
    if not buffers[buf] then
        return
    end
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
        if view.topline == 1 and view.topfill == 0 then
            vim.api.nvim_win_call(win, function()
                vim.fn.winrestview({ topline = 1, topfill = fill(win, 1) })
            end)
        end
    end
end

function M.first_hunk(buf)
    return buffers[buf] and buffers[buf].hunks[1]
end

return M
