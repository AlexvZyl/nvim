local config = require("review.config")
local deleted = require("review.deleted")
local git = require("review.git")
local render = require("review.render")
local session = require("review.session")
local state = require("review.state")

local M = {}

local namespace = vim.api.nvim_create_namespace("review_panel")
local done_namespace = vim.api.nvim_create_namespace("review_panel_done")
-- Of the selected file, by itself so another file selected only moves it.
local selected_namespace = vim.api.nvim_create_namespace("review_panel_selected")
-- Fills up as the review progresses.
local PROGRESS = { "󰪞", "󰪟", "󰪠", "󰪡", "󰪢", "󰪣", "󰪤" }
local EMPTY, DONE = "󰝦", "󰄴"
local FOLDER = ""
local ICON = ""
local buf, win, selected
-- Of the panel when another buffer was last opened in it.
local view
local rows = {}
-- Rows that end their directory group.
local group_ends = {}

local function show_top_header()
    -- Without a header above the first row the filler would be drawn as a diff filler line.
    vim.api.nvim_win_call(win, function()
        local top = vim.fn.winsaveview()
        if rows[1] and top.topline == 1 and top.topfill == 0 then
            vim.fn.winrestview({ topline = 1, topfill = 1 })
        end
    end)
end

-- Centered in the panel once no files are left.
local function show_done()
    vim.api.nvim_buf_clear_namespace(buf, done_namespace, 0, -1)
    if #rows > 0 then
        return
    end
    local count, undo = #session.files, config.options.keymaps.undo
    local message = { { DONE, "ReviewSignAdd" } }
    if count == 0 then
        table.insert(message, { "Nothing to review", "Comment" })
    else
        table.insert(message, { "Review complete", "Normal" })
        table.insert(message, { ("%d file%s reviewed"):format(count, count == 1 and "" or "s"), "Comment" })
        if undo then
            vim.list_extend(message, { { "", "Comment" }, { undo .. " to undo", "Comment" } })
        end
    end
    -- The empty buffer line takes the first row.
    local virt_lines = {}
    for _ = 1, math.floor((vim.api.nvim_win_get_height(win) - #message) / 2) - 1 do
        table.insert(virt_lines, { { "", "Normal" } })
    end
    for _, chunk in ipairs(message) do
        local pad = math.max(math.floor((vim.api.nvim_win_get_width(win) - vim.fn.strdisplaywidth(chunk[1])) / 2), 0)
        -- Padding in its own chunk, so it does not get the text's background.
        table.insert(virt_lines, { { string.rep(" ", pad), "Normal" }, chunk })
    end
    vim.api.nvim_buf_set_extmark(buf, done_namespace, 0, 0, { virt_lines = virt_lines, virt_lines_leftcol = true })
end

-- In the since_review view, the lines files reviewed then changed added and removed since the blob they were
-- reviewed at, kept on the file with that blob. Read for all of them by one git process, left as against the merge
-- base when git no longer has the blob.
local function count_since_review(files)
    local changed = {}
    for _, file in ipairs(files) do
        local reviewed = state.changed(file.key) and state.reviewed(file.key)
        if reviewed and file.added and not (file.since and file.since.blob == reviewed) then
            table.insert(changed, file)
        end
    end
    if #changed == 0 then
        return
    end
    local shown = git.show_each(
        vim.tbl_map(function(file)
            return file.path
        end, changed),
        {
            function(path)
                return state.reviewed(session.prefix .. path)
            end,
        }
    )
    for i, file in ipairs(changed) do
        local since = { blob = state.reviewed(file.key) }
        local reviewed = shown[i][1]
        if reviewed then
            -- Against the working tree like the counts of the diff, without carriage returns like the blob.
            local disk = io.open(file.path, "rb")
            local text = disk and disk:read("*a"):gsub("\r\n", "\n") or ""
            if disk then
                disk:close()
            end
            since.added, since.removed = 0, 0
            for _, hunk in ipairs(vim.text.diff(reviewed, text, { result_type = "indices" })) do
                since.removed, since.added = since.removed + hunk[2], since.added + hunk[4]
            end
        end
        file.since = since
    end
end

-- Lines the file added and removed, right aligned, since it was reviewed in that view. None for binary files.
local function counts(file)
    local since = config.options.view == "since_review" and file.since
    if not (since and since.added and since.blob == state.reviewed(file.key)) then
        since = file
    end
    local chunks = {}
    for _, count in ipairs({ { since.added, "+", "ReviewPanelAdded" }, { since.removed, "-", "ReviewPanelRemoved" } }) do
        if (count[1] or 0) > 0 then
            table.insert(chunks, { count[2] .. count[1] .. " ", count[3] })
        end
    end
    return chunks
end

local function mark_selected()
    vim.api.nvim_buf_clear_namespace(buf, selected_namespace, 0, -1)
    for i, file in ipairs(rows) do
        if file.key == selected then
            vim.api.nvim_buf_set_extmark(buf, selected_namespace, i - 1, 0, { line_hl_group = "ReviewPanelLine" })
            return i
        end
    end
end

-- The directory group, name, icon and its highlight of each file by path, for the depth they were grouped by.
local layouts, layouts_depth = {}, nil

local function layout(path)
    if layouts_depth ~= config.options.depth then
        layouts, layouts_depth = {}, config.options.depth
    end
    if not layouts[path] then
        local parts = vim.split(vim.fs.dirname(path), "/", { plain = true })
        local name = vim.fn.fnamemodify(path, ":t")
        local icon, hl = require("nvim-web-devicons").get_icon(name, nil, { default = true })
        layouts[path] = {
            dir = parts[1] == "." and "" or table.concat(parts, "/", 1, math.min(layouts_depth, #parts)),
            line = icon .. " " .. name,
            icon_end = #icon,
            hl = hl,
        }
    end
    return layouts[path]
end

-- With the cursor on the line, or on the selected file when not given, else the first.
local function draw(cursor)
    -- Pending files grouped by their first directories up to the configured depth.
    local groups, dirs = {}, {}
    for _, file in ipairs(session.files) do
        if state.pending(file.key) then
            local dir = layout(file.path).dir
            if not groups[dir] then
                groups[dir] = {}
                table.insert(dirs, dir)
            end
            table.insert(groups[dir], file)
        end
    end
    table.sort(dirs)
    rows, group_ends = {}, {}
    local lines, marks = {}, {}
    for _, dir in ipairs(dirs) do
        for i, file in ipairs(groups[dir]) do
            table.insert(rows, file)
            local shown = layout(file.path)
            table.insert(lines, shown.line)
            local dot = state.changed(file.key) and "ReviewChanged" or state.new(file.key) and "ReviewNew"
            table.insert(marks, {
                end_col = shown.icon_end,
                hl_group = shown.hl,
                virt_text = dot and { { " ●", dot } } or nil,
                virt_lines = i == 1 and { { { " " .. FOLDER .. (dir ~= "" and " " .. dir or ""), "ReviewPanelDir" } } } or nil,
                virt_lines_above = true,
                virt_lines_leftcol = true,
            })
        end
        group_ends[#rows] = true
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    if config.options.view == "since_review" then
        count_since_review(rows)
    end
    for i, mark in ipairs(marks) do
        vim.api.nvim_buf_set_extmark(buf, namespace, i - 1, 0, mark)
        if rows[i].deleted then
            vim.api.nvim_buf_set_extmark(buf, namespace, i - 1, mark.end_col + 1, { end_col = #lines[i], hl_group = "ReviewPanelDeleted" })
        end
        local count = counts(rows[i])
        if #count > 0 then
            vim.api.nvim_buf_set_extmark(buf, namespace, i - 1, 0, { virt_text = count, virt_text_pos = "right_align" })
        end
    end
    local selected_row = mark_selected()
    cursor = cursor or selected_row
    vim.api.nvim_win_set_cursor(win, { math.max(math.min(cursor or 1, #rows), 1), 0 })
    show_top_header()
    show_done()
    -- The winbar only redraws by itself on window events.
    vim.cmd.redrawstatus({ bang = true })
end

-- Redraws with the session as it is now, keeping the cursor.
function M.refresh()
    if M.is_open() then
        draw(vim.api.nvim_win_get_cursor(win)[1])
    end
end

local function remove(first, last)
    local keys = vim.tbl_map(function(file)
        return file.key
    end, vim.list_slice(rows, first, last))
    if #keys > 0 then
        state.review(keys, first)
        render.reviewed(keys)
        draw(first)
    end
end

local function restore(step)
    local cursor, keys = step(vim.fn.line("."))
    if cursor then
        render.reviewed(keys)
        draw(cursor)
    end
end

-- The window focused before the panel, another one or a new one.
local function target_window()
    for _, candidate in ipairs({ vim.fn.win_getid(vim.fn.winnr("#")), unpack(vim.api.nvim_tabpage_list_wins(0)) }) do
        if candidate ~= 0 and candidate ~= win and vim.api.nvim_win_get_config(candidate).relative == "" then
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
    if deleted.path(vim.api.nvim_win_get_buf(target)) == vim.fn.fnamemodify(file.path, ":.") then
        return marked and draw(line)
    end
    selected = file.key
    -- Drawn again only for the dot it no longer has.
    if marked then
        draw(line)
    else
        mark_selected()
    end
    vim.api.nvim_set_current_win(target)
    if file.deleted then
        vim.api.nvim_win_set_buf(target, deleted.open(file.path))
    else
        vim.cmd.edit(vim.fn.fnameescape(file.path))
        local first = render.first_hunk(vim.api.nvim_get_current_buf())
        if first then
            vim.api.nvim_win_set_cursor(0, { math.max(first.start, 1), 0 })
            vim.cmd("normal! zz")
            render.reveal(vim.api.nvim_get_current_buf())
        end
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
            view = vim.api.nvim_get_current_win() == win and vim.fn.winsaveview() or view
        end,
    })
    map("n", keys.open, select)
    map("n", "<2-LeftMouse>", select)
    map("n", keys.mark_reviewed, function()
        vim.o.operatorfunc = "v:lua.require'review.panel'.operator"
        return "g@"
    end, { expr = true })
    -- Doubling the key reviews the current line, like dd.
    map("o", keys.mark_reviewed, "_")
    map("n", keys.undo, function()
        restore(state.undo)
    end)
    map("n", keys.redo, function()
        restore(state.redo)
    end)
    map("x", keys.mark_reviewed, function()
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        vim.cmd("normal! \27")
        remove(math.min(first, last), math.max(first, last))
    end)
end

-- Another buffer opened in the panel, like with :edit or a picker while it is focused, goes to the window focused
-- before it instead. Right away, so it never shows in the panel. Focusing that window means whatever opened it
-- moves the cursor there after, like :edit +line or a picker.
function M.guard()
    if not (win and vim.api.nvim_win_is_valid(win) and buf and vim.api.nvim_buf_is_valid(buf)) then
        return
    end
    local opened = vim.api.nvim_win_get_buf(win)
    if opened == buf then
        return
    end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local target = target_window()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(view or {})
    end)
    vim.api.nvim_win_set_buf(target, opened)
    vim.api.nvim_win_set_cursor(target, cursor)
    vim.api.nvim_set_current_win(target)
end

function M.follow(opened)
    local key = session.prefix .. deleted.path(opened)
    if key ~= selected and session.by_key[key] then
        selected = key
        if M.is_open() then
            mark_selected()
        end
    end
end

-- In columns, of the editor's for a ratio.
local function width()
    local width = config.options.width
    return width < 1 and math.max(math.floor(vim.o.columns * width), 1) or width
end

-- Keeps a ratio of the editor's width once it resized.
function M.fit()
    if M.is_open() and config.options.width < 1 then
        vim.api.nvim_win_set_width(win, width())
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

local options = {
    number = true,
    relativenumber = false,
    cursorline = false,
    wrap = false,
    list = false,
    spell = false,
    winfixwidth = true,
    signcolumn = "no",
    statuscolumn = " %=%{%v:lua.require'review.panel'.number()%}%#WinSeparator# ",
    winbar = " " .. ICON .. " %{%v:lua.require'review.panel'.winbar()%}",
}

-- Loaded when given, like just after the review started. Otherwise shown as last loaded, and loaded again after,
-- which redraws it only when something changed meanwhile, as the watcher reloads it on what changes it.
function M.toggle(loaded)
    if M.is_open() then
        return M.close()
    end
    if not loaded then
        require("review.watch").schedule()
    end
    state.load()
    -- The file it is opened from, like once entered.
    local key = session.prefix .. deleted.path(vim.api.nvim_get_current_buf())
    if session.by_key[key] then
        selected = key
    end
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        create_buffer()
    end
    vim.cmd("topleft vertical " .. width() .. "split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    for option, value in pairs(options) do
        vim.wo[win][0][option] = value
    end
    draw()
end

-- Put back once set for every window with :set while in the panel, like a toggle of relative numbers in a config.
function M.option_set()
    local option = vim.fn.expand("<amatch>")
    if options[option] ~= nil and M.is_open() and vim.api.nvim_get_current_win() == win then
        vim.wo[win][0][option] = options[option]
    end
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
    local icon = done and DONE or percent == 0 and EMPTY or PROGRESS[math.max(math.ceil(percent * #PROGRESS / 100), 1)]
    local metrics = ("%d%%%% %s"):format(percent, icon)
    local branches = ("%s  %s"):format(session.source, session.ref)
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
