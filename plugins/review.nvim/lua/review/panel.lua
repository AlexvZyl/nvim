local config = require("review.config")
local render = require("review.render")
local session = require("review.session")
local state = require("review.state")

local M = {}

local namespace = vim.api.nvim_create_namespace("review_panel")
local done_namespace = vim.api.nvim_create_namespace("review_panel_done")
local MARK = "●"
-- Fills up as the review progresses.
local PROGRESS = { "󰪞", "󰪟", "󰪠", "󰪡", "󰪢", "󰪣", "󰪤" }
local EMPTY, DONE = "󰝦", "󰄴"
local FOLDER = ""
local ICON = ""
local buf, win, selected
-- Of the panel when another buffer was last opened in it.
local view
local rows = {}
local top_header = false
-- Rows that end their directory group.
local group_ends = {}

local function mark_text(key)
    if state.changed(key) then
        return { { " " .. MARK, "ReviewChanged" } }
    end
    if state.new(key) then
        return { { " " .. MARK, "ReviewNew" } }
    end
end

local function show_top_header()
    -- Without a header above the first row the filler would be drawn as a diff filler line.
    if not top_header then
        return
    end
    vim.api.nvim_win_call(win, function()
        local view = vim.fn.winsaveview()
        if view.topline == 1 and view.topfill == 0 then
            vim.fn.winrestview({ topline = 1, topfill = 1 })
        end
    end)
end

-- The first directories of a path up to the configured depth, empty for files in the root.
local function group_dir(path)
    local dir = vim.fs.dirname(path)
    if dir == "." then
        return ""
    end
    local parts = vim.split(dir, "/", { plain = true })
    return table.concat(parts, "/", 1, math.min(config.options.depth, #parts))
end

local function build_groups()
    local groups, dirs = {}, {}
    for _, file in ipairs(session.files) do
        if state.pending(file.key) then
            local dir = group_dir(file.path)
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

-- Centered in the panel once no files are left.
local function show_done()
    vim.api.nvim_buf_clear_namespace(buf, done_namespace, 0, -1)
    if #rows > 0 then
        return
    end
    local message = { { DONE, "ReviewSignAdd" } }
    if #session.files == 0 then
        table.insert(message, { "Nothing to review", "Comment" })
    else
        local count = #session.files
        table.insert(message, { "Review complete", "Normal" })
        table.insert(message, { string.format("%d file%s reviewed", count, count == 1 and "" or "s"), "Comment" })
        local undo = config.options.keymaps.undo
        if undo then
            table.insert(message, { "", "Comment" })
            table.insert(message, { undo .. " to undo", "Comment" })
        end
    end
    local width, height = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
    -- The empty buffer line takes the first row.
    local virt_lines = {}
    for _ = 1, math.floor((height - #message) / 2) - 1 do
        table.insert(virt_lines, { { "", "Normal" } })
    end
    for _, chunk in ipairs(message) do
        local pad = math.max(math.floor((width - vim.fn.strdisplaywidth(chunk[1])) / 2), 0)
        -- Padding in its own chunk, so it does not get the text's background.
        table.insert(virt_lines, { { string.rep(" ", pad), "Normal" }, chunk })
    end
    vim.api.nvim_buf_set_extmark(buf, done_namespace, 0, 0, { virt_lines = virt_lines, virt_lines_leftcol = true })
end

local function draw(cursor)
    local devicons = require("nvim-web-devicons")
    local groups = build_groups()
    rows = {}
    group_ends = {}
    local lines, marks, headers = {}, {}, {}
    for _, group in ipairs(groups) do
        headers[#rows + 1] = group.dir
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
        group_ends[#rows] = true
    end
    top_header = headers[1] ~= nil
    for line, dir in pairs(headers) do
        marks[line].virt_lines = { { { " " .. FOLDER .. (dir ~= "" and " " .. dir or ""), "ReviewPanelDir" } } }
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
    show_done()
    -- The winbar only redraws by itself on window events.
    vim.cmd.redrawstatus({ bang = true })
end

local function remove(first, last)
    local keys = {}
    for i = first, math.min(last, #rows) do
        table.insert(keys, rows[i].key)
    end
    if #keys == 0 then
        return
    end
    state.review(keys, first)
    draw(first)
end

local function restore(step)
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
    local line = vim.fn.line(".")
    local file = rows[line]
    if not file then
        return
    end
    local marked = state.changed(file.key) or state.new(file.key)
    if marked then
        state.clear(file.key)
    end
    local target = target_window()
    if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target)) == vim.fn.fnamemodify(file.path, ":p") then
        if marked then
            draw(line)
        end
        return
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
    local keys = config.options.keymaps
    local function map(mode, lhs, rhs, opts)
        if lhs then
            vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { buffer = buf }, opts or {}))
        end
    end
    vim.api.nvim_create_autocmd("CursorMoved", { buffer = buf, callback = show_top_header })
    -- To put it back as it was when another buffer is opened in the panel.
    vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = buf,
        callback = function()
            if vim.api.nvim_get_current_win() == win then
                view = vim.fn.winsaveview()
            end
        end,
    })
    map("n", keys.open, select)
    map("n", "<2-LeftMouse>", select)
    map("n", keys.review, function()
        vim.o.operatorfunc = "v:lua.require'review.panel'.operator"
        return "g@"
    end, { expr = true })
    -- Doubling the key reviews the current line, like dd.
    map("o", keys.review, "_")
    map("n", keys.undo, function()
        restore(state.undo)
    end)
    map("n", keys.redo, function()
        restore(state.redo)
    end)
    map("x", keys.review, function()
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        vim.cmd("normal! \27")
        remove(math.min(first, last), math.max(first, last))
    end)
end

-- Another buffer opened in the panel, like with :edit or a picker while it is focused, goes to the window focused
-- before it instead. Scheduled, so whatever opened it is done moving the cursor in it.
function M.guard()
    if not (win and vim.api.nvim_win_is_valid(win) and buf and vim.api.nvim_buf_is_valid(buf)) then
        return
    end
    if vim.api.nvim_win_get_buf(win) == buf then
        return
    end
    vim.schedule(function()
        if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
            return
        end
        local opened = vim.api.nvim_win_get_buf(win)
        if opened == buf then
            return
        end
        local cursor = vim.api.nvim_win_get_cursor(win)
        vim.api.nvim_win_set_buf(win, buf)
        if view then
            vim.api.nvim_win_call(win, function()
                vim.fn.winrestview(view)
            end)
        end
        local target = target_window()
        vim.api.nvim_win_set_buf(target, opened)
        vim.api.nvim_win_set_cursor(target, cursor)
        vim.api.nvim_set_current_win(target)
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

-- Redraws with the session as it is now, keeping the cursor.
function M.refresh()
    if M.is_open() then
        draw(vim.api.nvim_win_get_cursor(win)[1])
    end
end

function M.resized()
    if M.is_open() and vim.tbl_contains(vim.v.event.windows, win) then
        show_done()
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
    if not session.load() then
        return
    end
    state.load()
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        create_buffer()
    end
    vim.cmd("topleft vertical " .. config.options.width .. "split")
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
    wo.signcolumn = "no"
    wo.statuscolumn = " %=%{%v:lua.require'review.panel'.number()%}%#WinSeparator# "
    wo.winbar = " " .. ICON .. " %{%v:lua.require'review.panel'.winbar()%}"
    draw(1)
end

function M.winbar()
    local remaining = 0
    for _, row in ipairs(rows) do
        remaining = remaining + row.changes
    end
    local total = session.total_changes
    -- Only done once no files are left, however small, so binary files and an empty diff count too.
    local done = #rows == 0
    local percent = done and 100 or total > 0 and math.min(math.floor((total - remaining) / total * 100), 99) or 0
    local icon = done and DONE
        or percent == 0 and EMPTY
        or PROGRESS[math.max(math.ceil(percent * #PROGRESS / 100), 1)]
    local metrics = string.format("%d%%%% %s", percent, icon)
    local branches = string.format("%s  %s", session.source, session.ref)
    if vim.fn.strdisplaywidth(branches .. metrics) + 7 > vim.api.nvim_win_get_width(0) then
        branches = " " .. session.ref
    end
    return branches .. "%=" .. metrics .. " "
end

function M.number()
    local file = rows[vim.v.lnum]
    if not file then
        return ""
    end
    return (file.key == selected and "%#ReviewPanelNr#" or "") .. (group_ends[vim.v.lnum] and "└─" or "├─")
end

return M
