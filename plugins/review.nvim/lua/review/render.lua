-- Attaches buffers to Buffer objects and passes editor events on to them.
local Buffer = require("review.buffer")
local config = require("review.config")
local review_file = require("review.file")
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
local function number_group(winid, bufnr, row)
    local cursorlineopt = vim.wo[winid].cursorlineopt
    if vim.wo[winid].cursorline and (cursorlineopt:find("number") or cursorlineopt:find("both")) then
        local sign = vim.api.nvim_buf_get_extmarks(bufnr, Buffer.namespace, { row, 0 }, { row, 0 }, { details = true, overlap = true })[1]
        return sign and sign[4].number_hl_group
    end
end

local function mark_cursor(winid)
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local row = vim.api.nvim_win_get_cursor(winid)[1] - 1
    local group, tick, mark = number_group(winid, bufnr, row), vim.b[bufnr].changedtick, cursor_marks[winid]
    if mark and mark.bufnr == bufnr and mark.row == row and mark.group == group and mark.tick == tick then
        return
    end
    if mark and mark.id and vim.api.nvim_buf_is_valid(mark.bufnr) then
        vim.api.nvim_buf_del_extmark(mark.bufnr, mark.ns, mark.id)
    end
    local ns = mark and mark.ns
    if not ns then
        ns = table.remove(spare_namespaces) or vim.api.nvim_create_namespace("")
        vim.api.nvim__ns_set(ns, { wins = { winid } })
    end
    cursor_marks[winid] = {
        ns = ns,
        bufnr = bufnr,
        row = row,
        group = group,
        tick = tick,
        id = group and vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
            number_hl_group = group:gsub("Nr$", "CursorNr"),
            priority = config.options.sign_priority + 1,
        }),
    }
end

-- Clears marks of closed windows, keeping their namespaces.
local function prune_cursor_marks()
    for winid, mark in pairs(cursor_marks) do
        if not vim.api.nvim_win_is_valid(winid) then
            if vim.api.nvim_buf_is_valid(mark.bufnr) then
                vim.api.nvim_buf_clear_namespace(mark.bufnr, mark.ns, 0, -1)
            end
            table.insert(spare_namespaces, mark.ns)
            cursor_marks[winid] = nil
        end
    end
end

local function clear_cursor_marks(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    for _, mark in pairs(cursor_marks) do
        vim.api.nvim_buf_clear_namespace(bufnr, mark.ns, 0, -1)
    end
end

-- Buffers

-- Includes files that do not exist, to show deleted files.
local function attachable(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    return vim.bo[bufnr].buftype == "" and name ~= "" and vim.fn.isdirectory(name) == 0
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

-- Files at each revision are read from git unless given.
function M.attach(bufnr, files)
    if not attachable(bufnr) then
        return
    end
    files = files or review_file.read_each({ vim.api.nvim_buf_get_name(bufnr) }, revisions())[1]
    -- The reviewed version replaces the merge base, when git still has it.
    local head, base = files[1], files[3] and files[3].text and files[3] or files[2]
    -- Untracked or binary.
    local exists = head and head.text or base and base.text
    local binary = head and head:is_binary() or base and base:is_binary()
    if not exists or binary then
        return M.detach(bufnr)
    end
    local buffer = Buffer.get(bufnr) or Buffer.new(bufnr)
    buffer:set_files(base, head)
end

-- With one git process.
local function attach_each(bufnrs)
    if #bufnrs == 0 then
        return
    end
    local files = review_file.read_each(vim.tbl_map(vim.api.nvim_buf_get_name, bufnrs), revisions())
    for i, bufnr in ipairs(bufnrs) do
        M.attach(bufnr, files[i])
    end
end

function M.attach_all()
    attach_each(vim.tbl_filter(function(bufnr)
        return vim.api.nvim_buf_is_loaded(bufnr) and attachable(bufnr)
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
    for bufnr, buffer in Buffer.each() do
        local repo_path = session.cwd_prefix .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
        local reviewed_hash = session.reviewed_hash(repo_path)
        if changed[repo_path] and reviewed_hash and reviewed_hash == session.head_hashes()[repo_path] then
            -- Reviewed as in HEAD, which is already read.
            M.attach(bufnr, { buffer.head, nil, buffer.head })
        elseif changed[repo_path] then
            table.insert(to_read, bufnr)
        end
    end
    attach_each(to_read)
end

function M.detach(bufnr)
    local buffer = Buffer.get(bufnr)
    if buffer then
        buffer:detach()
        clear_cursor_marks(bufnr)
    end
end

function M.detach_all()
    for bufnr, buffer in Buffer.each() do
        buffer:detach()
        clear_cursor_marks(bufnr)
    end
end

function M.update(bufnr)
    local buffer = Buffer.get(bufnr)
    if buffer then
        buffer:update()
    end
end

-- Measures the gutter after each redraw, as a statuscolumn measures narrower before it.
local redrawn_winids = {}
vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace("review_deleted"), {
    on_win = function(_, winid, bufnr)
        redrawn_winids[winid] = Buffer.get(bufnr) and bufnr or nil
        return false
    end,
    on_end = function()
        for winid, bufnr in pairs(redrawn_winids) do
            local buffer = Buffer.get(bufnr)
            local gutter_width = vim.fn.getwininfo(winid)[1].textoff
            if buffer and winid == buffer:display_window() and gutter_width ~= buffer.gutter_width then
                vim.schedule(function()
                    buffer = Buffer.get(bufnr)
                    if buffer and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_win_is_valid(winid) then
                        buffer.gutter_width = gutter_width
                        buffer:refresh()
                    end
                end)
            end
        end
        redrawn_winids = {}
    end,
})

-- On SafeState: records the screen for scroll.keep and refreshes stale drawing.
function M.settled()
    prune_cursor_marks()
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        mark_cursor(winid)
        local buffer = Buffer.get(vim.api.nvim_win_get_buf(winid))
        if buffer and buffer.rendered_diff == buffer.from_base then
            buffer:refresh()
            scroll.settle(winid, buffer.rendered_lines)
        end
    end
end

-- Now, before the screen shows deleted lines unscrolled.
function M.scrolled()
    for key in pairs(vim.v.event) do
        local winid = tonumber(key)
        local buffer = winid and vim.api.nvim_win_is_valid(winid) and Buffer.get(vim.api.nvim_win_get_buf(winid))
        if buffer then
            buffer:refresh()
        end
    end
end

function M.reveal(bufnr)
    if Buffer.get(bufnr) then
        scroll.reveal(bufnr)
    end
end

-- Highlight group by changed line.
function M.changed_lines(bufnr)
    local buffer = Buffer.get(bufnr)
    return buffer and buffer.changed_lines or {}
end

function M.first_hunk(bufnr)
    local buffer = Buffer.get(bufnr)
    return buffer and buffer.from_base.hunks[1]
end

return M
