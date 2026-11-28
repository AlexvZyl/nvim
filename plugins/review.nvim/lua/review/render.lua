-- Attaches buffers to Buffer objects and passes editor events on to them.
local Buffer = require("review.buffer")
local config = require("review.config")
local git = require("review.git")
local scroll = require("review.scroll")
local session = require("review.session")

local M = {}

-- Cursor line numbers

-- Puts CursorLineNr back on the cursor line's number where a changed line's highlight hides it. One namespace per
-- window, as a buffer can show in several.
-- By window.
local cursor_marks = {}
-- From closed windows, for new ones.
local spare_namespaces = {}

-- The changed line's number group, nil when not changed or cursorline does not show numbers.
local function number_group(win, buf, row)
    local cursorlineopt = vim.wo[win].cursorlineopt
    if vim.wo[win].cursorline and (cursorlineopt:find("number") or cursorlineopt:find("both")) then
        local sign = vim.api.nvim_buf_get_extmarks(buf, Buffer.namespace, { row, 0 }, { row, 0 }, { details = true, overlap = true })[1]
        return sign and sign[4].number_hl_group
    end
end

local function mark_cursor(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local row = vim.api.nvim_win_get_cursor(win)[1] - 1
    local group, tick, mark = number_group(win, buf, row), vim.b[buf].changedtick, cursor_marks[win]
    if mark and mark.buf == buf and mark.row == row and mark.group == group and mark.tick == tick then
        return
    end
    if mark and mark.id and vim.api.nvim_buf_is_valid(mark.buf) then
        vim.api.nvim_buf_del_extmark(mark.buf, mark.ns, mark.id)
    end
    local ns = mark and mark.ns
    if not ns then
        ns = table.remove(spare_namespaces) or vim.api.nvim_create_namespace("")
        vim.api.nvim__ns_set(ns, { wins = { win } })
    end
    cursor_marks[win] = {
        ns = ns,
        buf = buf,
        row = row,
        group = group,
        tick = tick,
        id = group and vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
            number_hl_group = group:gsub("Nr$", "CursorNr"),
            priority = config.options.sign_priority + 1,
        }),
    }
end

-- Clears marks of closed windows, keeping their namespaces.
local function prune_cursor_marks()
    for win, mark in pairs(cursor_marks) do
        if not vim.api.nvim_win_is_valid(win) then
            if vim.api.nvim_buf_is_valid(mark.buf) then
                vim.api.nvim_buf_clear_namespace(mark.buf, mark.ns, 0, -1)
            end
            table.insert(spare_namespaces, mark.ns)
            cursor_marks[win] = nil
        end
    end
end

local function clear_cursor_marks(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    for _, mark in pairs(cursor_marks) do
        vim.api.nvim_buf_clear_namespace(buf, mark.ns, 0, -1)
    end
end

-- Buffers

-- Includes files that do not exist, to show deleted files.
local function attachable(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    return vim.bo[buf].buftype == "" and name ~= "" and vim.fn.isdirectory(name) == 0
end

-- HEAD, the merge base and, in the since_review view, the reviewed version.
local function revisions()
    local reviewed_version = config.options.view == "since_review"
        and function(path)
            local hash = session.reviewed_hash(session.cwd_prefix .. path)
            -- Empty when not in HEAD when reviewed.
            return hash ~= "" and hash or nil
        end
    return { "HEAD", session.merge_base, reviewed_version }
end

-- Contents are read from git unless given.
function M.attach(buf, contents)
    if not attachable(buf) then
        return
    end
    contents = contents or git.show_each({ vim.api.nvim_buf_get_name(buf) }, revisions())[1]
    -- The reviewed version replaces the merge base.
    local head_content, base_content = contents[1], contents[3] or contents[2]
    -- Untracked or binary.
    local either = (base_content or "") .. (head_content or "")
    if not (base_content or head_content) or either:find("\0", 1, true) then
        return M.detach(buf)
    end
    local buffer = Buffer.get(buf) or Buffer.new(buf)
    buffer:set_texts(head_content, base_content)
end

-- With one git process.
local function attach_each(bufs)
    if #bufs == 0 then
        return
    end
    local contents = git.show_each(vim.tbl_map(vim.api.nvim_buf_get_name, bufs), revisions())
    for i, buf in ipairs(bufs) do
        M.attach(buf, contents[i])
    end
end

function M.attach_all()
    attach_each(vim.tbl_filter(function(buf)
        return vim.api.nvim_buf_is_loaded(buf) and attachable(buf)
    end, vim.api.nvim_list_bufs()))
end

-- Rediffs buffers of files whose review changed, in the since_review view.
function M.review_changed(repo_paths)
    if config.options.view ~= "since_review" then
        return
    end
    local changed, to_read = {}, {}
    for _, repo_path in ipairs(repo_paths) do
        changed[repo_path] = true
    end
    for buf, buffer in Buffer.each() do
        local repo_path = session.cwd_prefix .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
        local reviewed_hash = session.reviewed_hash(repo_path)
        if changed[repo_path] and reviewed_hash and reviewed_hash == session.head_hashes()[repo_path] then
            -- Reviewed as in HEAD, which is already read.
            M.attach(buf, { buffer.head_text.content, nil, buffer.head_text.content })
        elseif changed[repo_path] then
            table.insert(to_read, buf)
        end
    end
    attach_each(to_read)
end

function M.detach(buf)
    local buffer = Buffer.get(buf)
    if buffer then
        buffer:detach()
        clear_cursor_marks(buf)
    end
end

function M.detach_all()
    for buf, buffer in Buffer.each() do
        buffer:detach()
        clear_cursor_marks(buf)
    end
end

function M.update(buf)
    local buffer = Buffer.get(buf)
    if buffer then
        buffer:update()
    end
end

-- Measures the gutter after each redraw, as a statuscolumn measures narrower before it.
local redrawn_wins = {}
vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace("review_deleted"), {
    on_win = function(_, win, buf)
        redrawn_wins[win] = Buffer.get(buf) and buf or nil
        return false
    end,
    on_end = function()
        for win, buf in pairs(redrawn_wins) do
            local buffer = Buffer.get(buf)
            local gutter_width = vim.fn.getwininfo(win)[1].textoff
            if buffer and win == buffer:display_window() and gutter_width ~= buffer.gutter_width then
                vim.schedule(function()
                    buffer = Buffer.get(buf)
                    if buffer and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win) then
                        buffer.gutter_width = gutter_width
                        buffer:refresh()
                    end
                end)
            end
        end
        redrawn_wins = {}
    end,
})

-- On SafeState: records the screen for scroll.keep and refreshes stale drawing.
function M.settled()
    prune_cursor_marks()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        mark_cursor(win)
        local buffer = Buffer.get(vim.api.nvim_win_get_buf(win))
        if buffer and buffer.rendered_hunks == buffer.hunks_from_base then
            buffer:refresh()
            scroll.settle(win, buffer.rendered_lines)
        end
    end
end

-- Now, before the screen shows deleted lines unscrolled.
function M.scrolled()
    for key in pairs(vim.v.event) do
        local win = tonumber(key)
        local buffer = win and vim.api.nvim_win_is_valid(win) and Buffer.get(vim.api.nvim_win_get_buf(win))
        if buffer then
            buffer:refresh()
        end
    end
end

function M.reveal(buf)
    if Buffer.get(buf) then
        scroll.reveal(buf)
    end
end

-- Highlight group by changed line.
function M.changed_lines(buf)
    local buffer = Buffer.get(buf)
    return buffer and buffer.changed_lines or {}
end

function M.first_hunk(buf)
    local buffer = Buffer.get(buf)
    return buffer and buffer.hunks_from_base[1]
end

return M
