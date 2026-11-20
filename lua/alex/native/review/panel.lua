local git = require("alex.native.review.git")
local render = require("alex.native.review.render")
local session = require("alex.native.review.session")
local state = require("alex.native.review.state")

local M = {}

local namespace = vim.api.nvim_create_namespace("review_panel")
local WIDTH = 60
local MARK = "●"
local FOLDER = ""
local buf, win, selected
local rows = {}

local function mark_text(key)
    if state.changed(key) then
        return { { " " .. MARK, "ReviewChanged" } }
    end
    if state.new(key) then
        return { { " " .. MARK, "ReviewNew" } }
    end
end

local function show_top_header()
    vim.api.nvim_win_call(win, function()
        local view = vim.fn.winsaveview()
        if view.topline == 1 and view.topfill == 0 then
            vim.fn.winrestview({ topline = 1, topfill = 1 })
        end
    end)
end

local function build_groups()
    local groups, dirs = {}, {}
    for _, file in ipairs(session.files) do
        if state.pending(file.key) then
            local dir = file.path:match("^([^/]+)/") or ""
            if not groups[dir] then
                groups[dir] = {}
                table.insert(dirs, dir)
            end
            table.insert(groups[dir], file)
        end
    end
    table.sort(dirs)
    return vim.tbl_map(function(dir)
        return { dir = dir, files = groups[dir] }
    end, dirs)
end

local function draw(cursor)
    local devicons = require("nvim-web-devicons")
    local groups = build_groups()
    rows = {}
    local lines, marks, headers = {}, {}, {}
    for _, group in ipairs(groups) do
        if group.dir ~= "" then
            headers[#rows + 1] = group.dir
        end
        for _, file in ipairs(group.files) do
            table.insert(rows, file)
            local name = vim.fn.fnamemodify(file.path, ":t")
            local icon, hl = devicons.get_icon(name, nil, { default = true })
            table.insert(lines, icon .. " " .. name)
            table.insert(marks, {
                end_col = #icon,
                hl_group = hl,
                line_hl_group = file.key == selected and "ReviewPanelLine" or nil,
                virt_text = mark_text(file.key),
            })
        end
    end
    for line, dir in pairs(headers) do
        marks[line].virt_lines = { { { " " .. FOLDER .. " " .. dir, "ReviewPanelDir" } } }
        marks[line].virt_lines_above = true
        marks[line].virt_lines_leftcol = true
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for i, mark in ipairs(marks) do
        vim.api.nvim_buf_set_extmark(buf, namespace, i - 1, 0, mark)
    end
    vim.api.nvim_win_set_cursor(win, { math.max(math.min(cursor, #rows), 1), 0 })
    show_top_header()
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
    draw(1)
    vim.notify("Branch changed to " .. session.source .. ", review state reloaded", vim.log.levels.WARN)
    return false
end

local function remove(first, last)
    local keys = {}
    for i = first, math.min(last, #rows) do
        table.insert(keys, rows[i].key)
    end
    if #keys == 0 or not sync() then
        return
    end
    state.review(keys, first)
    draw(first)
end

local function restore(step)
    if not sync() then
        return
    end
    local cursor = step(vim.fn.line("."))
    if cursor then
        draw(cursor)
    end
end

local function target_window()
    local previous = vim.fn.win_getid(vim.fn.winnr("#"))
    if previous ~= 0 and previous ~= win and vim.api.nvim_win_get_config(previous).relative == "" then
        return previous
    end
    for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if candidate ~= win and vim.api.nvim_win_get_config(candidate).relative == "" then
            return candidate
        end
    end
    vim.cmd("botright vnew")
    return vim.api.nvim_get_current_win()
end

local function select()
    if not sync() then
        return
    end
    local line = vim.fn.line(".")
    local file = rows[line]
    if not file then
        return
    end
    local target = target_window()
    if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target)) == vim.fn.fnamemodify(file.path, ":p") then
        return
    end
    if state.changed(file.key) or state.new(file.key) then
        state.clear(file.key)
    end
    selected = file.key
    draw(line)
    vim.api.nvim_set_current_win(target)
    vim.cmd.edit(vim.fn.fnameescape(file.path))
    local first = render.first_hunk(vim.api.nvim_get_current_buf())
    if first then
        vim.api.nvim_win_set_cursor(0, { math.max(first.start, 1), 0 })
        vim.cmd("normal! zz")
    end
    vim.api.nvim_set_current_win(win)
end

local function create_buffer()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "review"
    local function map(mode, lhs, rhs)
        vim.keymap.set(mode, lhs, rhs, { buffer = buf })
    end
    vim.api.nvim_create_autocmd("CursorMoved", { buffer = buf, callback = show_top_header })
    map("n", "<CR>", select)
    map("n", "<2-LeftMouse>", select)
    vim.keymap.set("n", "d", function()
        vim.o.operatorfunc = "v:lua.require'alex.native.review.panel'.operator"
        return "g@"
    end, { buffer = buf, expr = true })
    map("o", "d", "_")
    map("n", "u", function()
        restore(state.undo)
    end)
    map("n", "<C-r>", function()
        restore(state.redo)
    end)
    map("x", "d", function()
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        vim.cmd("normal! \27")
        remove(math.min(first, last), math.max(first, last))
    end)
end

function M.follow(buf)
    local key = session.prefix .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
    if key == selected or not session.by_key[key] then
        return
    end
    selected = key
    if M.is_open() then
        draw(vim.api.nvim_win_get_cursor(win)[1])
    end
end

function M.operator()
    remove(vim.fn.line("'["), vim.fn.line("']"))
end

function M.is_open()
    return win ~= nil and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf
end

function M.close()
    if M.is_open() then
        pcall(vim.api.nvim_win_close, win, false)
    end
end

function M.toggle()
    if M.is_open() then
        return M.close()
    end
    if not git.load() then
        return
    end
    state.load()
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        create_buffer()
    end
    vim.cmd("topleft vertical " .. WIDTH .. "split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    local wo = vim.wo[win][0]
    wo.number = true
    wo.relativenumber = false
    wo.cursorline = false
    wo.wrap = false
    wo.list = false
    wo.spell = false
    wo.winfixwidth = true
    require("alex.native.statuscolumn").review()
    draw(1)
end

function M.winbar()
    local remaining = 0
    for _, row in ipairs(rows) do
        remaining = remaining + row.changes
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
    local file = rows[vim.v.lnum]
    if not file then
        return ""
    end
    return (file.key == selected and "%#ReviewPanelNr#" or "") .. vim.v.lnum
end

return M
