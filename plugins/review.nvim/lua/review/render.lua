local config = require("review.config")
local git = require("review.git")
local session = require("review.session")

local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local deleted_namespace = vim.api.nvim_create_namespace("review_deleted")
local anchor_namespace = vim.api.nvim_create_namespace("review_anchor")
-- Committed and uncommitted.
local SIGNS = { [false] = "│", [true] = "╎" }
local DELETED_PREFIX = "review://"
-- Attached buffers, with the file at the merge base and the current hunks against it.
local buffers = {}

-- Hunks from the file to the text, with the lines of the file they delete.
local function diff(from, to)
    local hunks = {}
    for _, hunk in ipairs(vim.text.diff(from.text, to, { result_type = "indices", indent_heuristic = true })) do
        local old, deleted, start, count = unpack(hunk)
        table.insert(hunks, { old = old, start = start, count = count, deleted = vim.list_slice(from.lines, old, old + deleted - 1) })
    end
    return hunks
end

-- The highlight groups of changed lines, kind being Add or Delete.
local function sign(buf, first, last, uncommitted, kind)
    local group = "Review" .. (uncommitted and "Local" or "") .. kind
    vim.api.nvim_buf_set_extmark(buf, namespace, first - 1, 0, {
        end_row = last - 1,
        line_hl_group = group,
        number_hl_group = group .. "Nr",
        sign_text = SIGNS[uncommitted],
        sign_hl_group = "ReviewSign" .. group:sub(7),
        priority = config.options.sign_priority,
    })
end

local function view(win)
    return vim.api.nvim_win_call(win, vim.fn.winsaveview)
end

local function restore(win, saved)
    vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(saved)
    end)
end

-- Treesitter highlight of every byte of the deleted lines, by line.
local function highlight_deleted(lang, deleted)
    local highlights = {}
    local query = lang and vim.treesitter.query.get(lang, "highlights")
    local source = table.concat(deleted, "\n")
    local ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
    if not query or not ok then
        return highlights
    end
    for id, node in query:iter_captures(parser:parse()[1]:root(), source) do
        local name = query.captures[id]
        if not name:find("^_") and name ~= "spell" and name ~= "nospell" then
            local start_row, start_col, end_row, end_col = node:range()
            for row = start_row, math.min(end_row, #deleted - 1) do
                highlights[row + 1] = highlights[row + 1] or {}
                for col = (row == start_row and start_col or 0) + 1, row == end_row and end_col or #deleted[row + 1] do
                    highlights[row + 1][col] = "@" .. name .. "." .. lang
                end
            end
        end
    end
    return highlights
end

-- Virtual text of a deleted line, scrolled by leftcol and padded to the edge like a line highlight.
local function deleted_chunks(text, highlights, uncommitted, leftcol, tabstop)
    local base = uncommitted and "ReviewLocalDelete" or "ReviewDelete"
    local chunks, width, byte, last = {}, 0, 1, nil
    -- A UTF-8 lead byte followed by its continuation bytes.
    for char in text:gmatch("[^\128-\191][\128-\191]*") do
        local name = highlights[byte]
        local cells = char == "\t" and tabstop or 1
        byte, width = byte + #char, width + cells
        local shown = math.min(cells, width - leftcol)
        if shown > 0 then
            char = char == "\t" and string.rep(" ", shown) or char
            -- Neighbouring characters with the same highlight go in one chunk.
            if chunks[1] and name == last then
                chunks[#chunks][1] = chunks[#chunks][1] .. char
            else
                table.insert(chunks, { char, name and { base, name } or base })
            end
            last = name
        end
    end
    table.insert(chunks, { string.rep(" ", math.max(vim.o.columns - width + leftcol, 0)), base })
    return chunks
end

local function window(buf)
    return vim.fn.win_findbuf(buf)[1] or vim.api.nvim_get_current_win()
end

-- Width of the gutter.
local function textoff(buf)
    return vim.fn.getwininfo(window(buf))[1].textoff
end

-- The number and sign columns of a changed line, for virtual lines, which have none.
function M.gutter(buf, uncommitted, kind)
    local width = buffers[buf] and buffers[buf].textoff or textoff(buf)
    local sign = SIGNS[uncommitted] .. string.rep(" ", width - 2)
    return { { " ", "LineNr" }, { sign, "ReviewSign" .. (uncommitted and "Local" or "") .. kind } }
end

-- Drawn separately from the added lines, since they depend on the window's scroll and gutter. Marks already showing
-- the right lines in the right place are kept, so an edit only redraws the deleted lines it changed.
local function render_deleted(buf)
    local attached = buffers[buf]
    -- As last seen after a redraw. Right after an edit, before the redraw, a statuscolumn is not measured yet.
    attached.textoff = attached.textoff or textoff(buf)
    local leftcol, tabstop = view(window(buf)).leftcol, vim.bo[buf].tabstop
    local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    -- Every line is drawn again when how they are drawn changed.
    local style = table.concat({ leftcol, tabstop, attached.textoff, vim.o.columns, lang or "" }, " ")
    if attached.style ~= style then
        vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
        attached.style, attached.drawn = style, {}
    end
    local line_count = vim.api.nvim_buf_line_count(buf)
    -- The deleted lines by where they go, each with where it was in HEAD to order them by.
    local anchors, rows = {}, {}
    -- Deleted by commits against the base, and everything deleted against HEAD as uncommitted.
    for uncommitted, hunks in pairs({ [false] = attached.hunks, [true] = attached.local_hunks }) do
        for _, hunk in ipairs(hunks) do
            -- A pure deletion starts at the line before it, so goes above the line after it unless it is at the end.
            local row = hunk.count > 0 and hunk.start - 1 or hunk.start
            for i in ipairs(hunk.deleted) do
                local key = uncommitted and hunk.old + i - 1 or attached.committed_deletions[hunk.old + i - 1]
                if key then
                    if not anchors[row] then
                        anchors[row] = {}
                        table.insert(rows, row)
                    end
                    table.insert(anchors[row], { key = key, order = i, hunk = hunk, uncommitted = uncommitted })
                end
            end
        end
    end
    -- The marks drawn before, by where they are now and what they show.
    local drawn, existing = {}, {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, deleted_namespace, 0, -1, {})) do
        existing[mark[2] .. attached.drawn[mark[1]]] = mark[1]
    end
    for _, row in ipairs(rows) do
        local lines = anchors[row]
        table.sort(lines, function(a, b)
            return a.key == b.key and a.order < b.order or a.key < b.key
        end)
        local above = row < line_count
        row = above and row or line_count - 1
        local shown = above and "^" or "v"
        for _, line in ipairs(lines) do
            shown = shown .. (line.uncommitted and "\n+" or "\n-") .. line.hunk.deleted[line.order]
        end
        local id = existing[row .. shown]
        if not id or drawn[id] then
            id = vim.api.nvim_buf_set_extmark(buf, deleted_namespace, row, 0, {
                virt_lines = vim.tbl_map(function(line)
                    local hunk = line.hunk
                    local cached = (lang or "") .. "\n" .. table.concat(hunk.deleted, "\n")
                    attached.highlights[cached] = attached.highlights[cached] or highlight_deleted(lang, hunk.deleted)
                    local chunks = deleted_chunks(hunk.deleted[line.order], attached.highlights[cached][line.order] or {}, line.uncommitted, leftcol, tabstop)
                    return vim.list_extend(M.gutter(buf, line.uncommitted, "Delete"), chunks)
                end, lines),
                virt_lines_above = above,
                virt_lines_leftcol = true,
                -- Left gravity keeps lines inserted at the mark, like an undone delete, below the deleted lines.
                right_gravity = false,
            })
        end
        drawn[id] = shown
    end
    for id in pairs(attached.drawn) do
        if not drawn[id] then
            vim.api.nvim_buf_del_extmark(buf, deleted_namespace, id)
        end
    end
    attached.drawn = drawn
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

-- By window, the screen row of the cursor line as last seen with the hunks rendered, and a mark at its start
-- that moves with the edits. Measured once an edit is made, the stale virtual lines have already moved.
local settled_rows = {}

local function settle(win, buf)
    local line, count = vim.api.nvim_win_get_cursor(win)[1], vim.api.nvim_buf_line_count(buf)
    -- Over the whole line with its line break, so it is only invalidated when the line is deleted.
    local last = line == count
    vim.api.nvim_buf_set_extmark(buf, anchor_namespace, line - 1, 0, {
        id = win,
        end_row = last and line - 1 or line,
        end_col = last and #vim.api.nvim_buf_get_lines(buf, line - 1, line, true)[1] or 0,
        invalidate = true,
        undo_restore = false,
    })
    local top = view(win)
    settled_rows[win] = {
        buf = buf,
        line = line,
        count = count,
        row = line_row(win, line),
        topline = top.topline,
        topfill = top.topfill,
        fill = fill(win, top.topline),
    }
end

-- Scrolls so the line the cursor was on stays in place on screen when edited. The deleted lines added or removed
-- above it then do not move it, while the cursor still moves with the edit.
local function keep_cursor(buf)
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
            -- Off screen when the mark was, which is left to Vim.
            if line_row(win, settled.line) ~= settled.row and settled.row >= 0 and settled.row < vim.api.nvim_win_get_height(win) then
                scroll_to(win, settled.line, settled.row)
            end
        elseif mark then
            -- Shows the deleted lines that came above the top line, like when the lines at the top are deleted, and
            -- hides them again once they go, like when that is undone.
            local top = view(win)
            local above = fill(win, top.topline)
            if top.topline == settled.topline and above ~= settled.fill then
                restore(win, { topline = top.topline, topfill = math.max(math.min(settled.topfill + above - settled.fill, above), 0) })
            end
            -- Deleting up, from the last of the deleted lines like `dk` or a selection up, goes on the line above
            -- them so the cursor stays at the top. Deleting down leaves it below them.
            local cursor = vim.api.nvim_win_get_cursor(win)[1]
            local removed = settled.count - vim.api.nvim_buf_line_count(buf)
            if deleted and removed > 1 and (settled.visual or settled.line) == cursor + removed - 1 and cursor > 1 then
                local text = vim.api.nvim_buf_get_lines(buf, cursor - 2, cursor - 1, true)[1]
                vim.api.nvim_win_set_cursor(win, { cursor - 1, #text:match("^%s*") })
            end
        end
        settle(win, buf)
    end
end

local function render(buf)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    -- The highlight of each added line, signed in runs of the same.
    local changed, first = {}, nil
    for i, hunks in ipairs({ buffers[buf].hunks, buffers[buf].local_hunks }) do
        for _, hunk in ipairs(hunks) do
            for line = hunk.start, hunk.start + hunk.count - 1 do
                changed[line] = i == 1 and "ReviewAdd" or "ReviewLocalAdd"
            end
        end
    end
    for line = 1, vim.api.nvim_buf_line_count(buf) + 1 do
        if first and changed[line] ~= changed[first] then
            sign(buf, first, line - 1, changed[first] == "ReviewLocalAdd", "Add")
            first = nil
        end
        first = first or changed[line] and line
    end
    buffers[buf].changed = changed
    render_deleted(buf)
    require("review.diagnostics").apply(buf)
end

-- Draws the deleted lines again once the gutter they draw in or the width they are padded to changed.
local function follow_width(buf)
    local width = textoff(buf)
    if buffers[buf].textoff ~= width or buffers[buf].columns ~= vim.o.columns then
        buffers[buf].textoff, buffers[buf].columns = width, vim.o.columns
        render_deleted(buf)
        require("review.diagnostics").apply(buf)
    end
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

-- Diffs the buffer against the merge base in memory, so edits show up while typing.
function M.update(buf)
    local attached = buffers[buf]
    if not attached or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Like the file is written, with the line break at the end unless it had none when read.
    local text = (#lines == 1 and lines[1] == "") and "" or table.concat(lines, "\n") .. (vim.bo[buf].eol and "\n" or "")
    local hunks = diff(attached.base, text)
    -- Without commits to the file everything is uncommitted.
    attached.hunks = hunks
    attached.local_hunks = attached.head.text == attached.base.text and hunks or diff(attached.head, text)
    -- Right away, as TextChanged comes before the redraw: scheduled, the edit would show without the deleted
    -- lines for a moment.
    render(buf)
    keep_cursor(buf)
    attached.rendered = hunks
    -- The width of the gutter the deleted lines draw in is only right after the redraw.
    vim.schedule(function()
        if buffers[buf] == attached and attached.hunks == hunks and vim.api.nvim_buf_is_valid(buf) then
            follow_width(buf)
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

-- Once the screen shows the rendered hunks, so cursor moves and scrolls are kept by the next render. The gutter
-- and the width can also have changed without an edit, like with :set number or a resize.
function M.settled()
    local rows = settled_rows
    settled_rows = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if buffers[buf] and buffers[buf].rendered == buffers[buf].hunks then
            follow_width(buf)
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
    -- No base when the file was added since the merge base, no head when it was added since HEAD.
    local base = session.merge_base and git.show(session.merge_base, file)
    local head = git.show("HEAD", file)
    if (not base and not head) or (base or ""):find("\0", 1, true) or (head or ""):find("\0", 1, true) then
        -- Untracked, outside the repo or binary.
        return M.detach(buf)
    end
    if not buffers[buf] then
        buffers[buf] = { hunks = {}, drawn = {} }
        for key, forward in pairs({ next_hunk = true, prev_hunk = false }) do
            if config.options.keymaps[key] then
                vim.keymap.set("n", config.options.keymaps[key], function()
                    jump(buf, forward)
                end, { buffer = buf })
            end
        end
    end
    local attached = buffers[buf]
    attached.base = { text = base or "", lines = vim.split(base or "", "\n") }
    attached.head = { text = head or "", lines = vim.split(head or "", "\n") }
    -- Treesitter highlights of deleted lines, by their language and text.
    attached.highlights = {}
    -- Lines of the base deleted by commits, other deleted lines are only deleted locally. With where they were
    -- between the lines of HEAD: after the line before them, or before the lines that replaced them.
    attached.committed_deletions = {}
    for _, hunk in ipairs(diff(attached.base, attached.head.text)) do
        for i = 1, #hunk.deleted do
            attached.committed_deletions[hunk.old + i - 1] = hunk.count == 0 and hunk.start + 0.5 or hunk.start - 0.5
        end
    end
    M.update(buf)
end

function M.attach_all()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            M.attach(buf)
        end
    end
end

function M.detach(buf)
    if not buffers[buf] then
        return
    end
    buffers[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) then
        for _, ns in ipairs({ namespace, deleted_namespace, anchor_namespace }) do
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        end
        for _, key in ipairs({ config.options.keymaps.next_hunk, config.options.keymaps.prev_hunk }) do
            pcall(vim.keymap.del, "n", key, { buffer = buf })
        end
    end
end

-- Detaches every buffer and wipes those of deleted files.
function M.detach_all()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        M.detach(buf)
        if vim.startswith(vim.api.nvim_buf_get_name(buf), DELETED_PREFIX) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
end

function M.scrolled()
    for win, delta in pairs(vim.v.event) do
        local id = tonumber(win)
        if id and delta.leftcol ~= 0 and vim.api.nvim_win_is_valid(id) and buffers[vim.api.nvim_win_get_buf(id)] then
            render_deleted(vim.api.nvim_win_get_buf(id))
        end
    end
end

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
    sign(buf, 1, #lines, uncommitted, "Delete")
end

function M.deleted_buffer(path)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(buf) == DELETED_PREFIX .. path then
            return buf
        end
    end
    -- Not with bufadd, whose options are reset when it is first shown in a window.
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, DELETED_PREFIX .. path)
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
    for _, win in ipairs(buffers[buf] and vim.fn.win_findbuf(buf) or {}) do
        local top = view(win)
        if top.topline == 1 and top.topfill == 0 then
            restore(win, { topline = 1, topfill = fill(win, 1) })
        end
    end
end

-- The highlight of each changed line, as last rendered.
function M.changed(buf)
    return buffers[buf] and buffers[buf].changed or {}
end

function M.first_hunk(buf)
    return buffers[buf] and buffers[buf].hunks[1]
end

return M
