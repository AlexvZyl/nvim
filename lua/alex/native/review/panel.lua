local git = require("alex.native.review.git")
local render = require("alex.native.review.render")
local session = require("alex.native.review.session")
local state = require("alex.native.review.state")

local M = {}

local namespace = vim.api.nvim_create_namespace("review_panel")
local WIDTH = 60
local TITLE = "review"
local MARK = "●"
local TEXT_FUNC = "v:lua.require'alex.native.review.panel'.text"

local function is_review_list()
    return vim.fn.getqflist({ title = 0 }).title == TITLE
end

local function build_items()
    local items = {}
    for _, file in ipairs(session.files) do
        if state.pending(file.key) then
            table.insert(items, { filename = file.path, lnum = 1, col = 1, text = "", user_data = file.key })
        end
    end
    return items
end

local function mark_text(key)
    if state.changed(key) then
        return { { " " .. MARK, "ReviewChanged" } }
    end
    if state.new(key) then
        return { { " " .. MARK, "ReviewNew" } }
    end
end

local function highlight(buf)
    local devicons = require("nvim-web-devicons")
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for i, item in ipairs(vim.fn.getqflist()) do
        local name = vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ":t")
        local icon, hl = devicons.get_icon(name, nil, { default = true })
        vim.api.nvim_buf_set_extmark(buf, namespace, i - 1, 0, {
            end_col = #icon,
            hl_group = hl,
            virt_text = mark_text(item.user_data),
        })
    end
end

local function refresh(cursor)
    local items = build_items()
    local idx = vim.fn.getqflist({ idx = 0 }).idx
    vim.fn.setqflist({}, "r", {
        items = items,
        title = TITLE,
        quickfixtextfunc = TEXT_FUNC,
        idx = math.max(math.min(idx, #items), 1),
    })
    highlight(vim.api.nvim_get_current_buf())
    vim.api.nvim_win_set_cursor(0, { math.max(math.min(cursor, #items), 1), 0 })
end

local function sync()
    local source = session.source
    if not git.load() then
        return false
    end
    if source == session.source then
        return true
    end
    state.load()
    refresh(1)
    vim.notify("Branch changed to " .. session.source .. ", review state reloaded", vim.log.levels.WARN)
    return false
end

local function remove(first, last)
    if not is_review_list() then
        return
    end
    local items = vim.fn.getqflist()
    local keys = {}
    for i = first, math.min(last, #items) do
        table.insert(keys, items[i].user_data)
    end
    if #keys == 0 or not sync() then
        return
    end
    state.review(keys, first)
    refresh(first)
end

local function restore(step)
    if not is_review_list() or not sync() then
        return
    end
    local cursor = step(vim.fn.line("."))
    if cursor then
        refresh(cursor)
    end
end

local function select()
    local line = vim.fn.line(".")
    if not is_review_list() then
        return vim.cmd(line .. "cc")
    end
    if not sync() then
        return
    end
    local item = vim.fn.getqflist()[line]
    if item and (state.changed(item.user_data) or state.new(item.user_data)) then
        state.clear(item.user_data)
        refresh(line)
    end
    vim.cmd(line .. "cc")
    local first = render.first_hunk(vim.api.nvim_get_current_buf())
    if first then
        vim.api.nvim_win_set_cursor(0, { math.max(first.start, 1), 0 })
        vim.cmd("normal! zz")
    end
    vim.cmd("wincmd p")
end

local function set_keymaps(buf)
    vim.keymap.set("n", "<CR>", select, { buffer = buf })
    vim.keymap.set("n", "<2-LeftMouse>", select, { buffer = buf })
    vim.keymap.set("n", "dd", function()
        local line = vim.fn.line(".")
        remove(line, line)
    end, { buffer = buf })
    vim.keymap.set("n", "u", function()
        restore(state.undo)
    end, { buffer = buf })
    vim.keymap.set("n", "<C-r>", function()
        restore(state.redo)
    end, { buffer = buf })
    vim.keymap.set("x", "d", function()
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        vim.cmd("normal! \27")
        remove(math.min(first, last), math.max(first, last))
    end, { buffer = buf })
end

local function open()
    vim.cmd("topleft vertical copen " .. WIDTH)
    local buf = vim.api.nvim_get_current_buf()
    highlight(buf)
    vim.wo.relativenumber = false
    vim.wo.winhighlight = "QuickFixLine:ReviewQuickFixLine,qfFileName:Normal"
    vim.wo.cursorline = false
    vim.wo.statuscolumn = " %s%=%{%v:lua.require'alex.native.review.panel'.number()%}%#WinSeparator#  "
    set_keymaps(buf)
end

local function review_list()
    for nr = 1, vim.fn.getqflist({ nr = "$" }).nr do
        if vim.fn.getqflist({ nr = nr, title = 0 }).title == TITLE then
            return nr
        end
    end
end

local function window()
    for _, info in ipairs(vim.fn.getwininfo()) do
        if info.tabnr == vim.fn.tabpagenr() and info.quickfix == 1 and info.loclist == 0 then
            return info.winid
        end
    end
end

function M.is_open()
    return window() ~= nil and is_review_list()
end

function M.toggle()
    if M.is_open() then
        return vim.cmd("cclose")
    end
    if not git.load() then
        return
    end
    state.load()
    local nr = review_list()
    if nr then
        vim.cmd("silent " .. nr .. "chistory")
    end
    vim.fn.setqflist({}, nr and "r" or " ", {
        items = build_items(),
        title = TITLE,
        quickfixtextfunc = TEXT_FUNC,
    })
    open()
end

function M.winbar()
    if not is_review_list() then
        return nil
    end
    local remaining = 0
    for _, item in ipairs(vim.fn.getqflist()) do
        local file = session.by_key[item.user_data]
        remaining = remaining + (file and file.changes or 0)
    end
    local total = session.total_changes
    local percent = total > 0 and math.floor(remaining / total * 100 + 0.5) or 0
    local metrics = string.format(" %d%%", percent)
    local branches = string.format("%s  %s", session.source, session.ref)
    if vim.fn.strdisplaywidth(branches .. metrics) + 7 > vim.api.nvim_win_get_width(0) then
        branches = " " .. session.ref
    end
    return branches .. "%=" .. metrics:gsub("%%", "%%%%") .. " "
end

function M.number()
    local selected = vim.v.lnum == vim.fn.getqflist({ idx = 0 }).idx
    return (selected and "%#ReviewQuickFixNr#" or "") .. vim.v.lnum
end

function M.text(info)
    local items = vim.fn.getqflist({ id = info.id, items = 0 }).items
    local devicons = require("nvim-web-devicons")
    local lines = {}
    for i = info.start_idx, info.end_idx do
        local name = vim.fn.fnamemodify(vim.fn.bufname(items[i].bufnr), ":t")
        local icon = devicons.get_icon(name, nil, { default = true })
        table.insert(lines, icon .. " " .. name)
    end
    return lines
end

return M
