-- The side panel of files to review: its rows, window, keymaps and drawing.
local config = require("review.config")
local deleted = require("review.deleted")
local render = require("review.render")
local session = require("review.session")

local M = {}

local rows_namespace = vim.api.nvim_create_namespace("review_panel")
local done_namespace = vim.api.nvim_create_namespace("review_panel_done")
-- Own namespace, so selecting another file only moves it.
local selected_namespace = vim.api.nvim_create_namespace("review_panel_selected")
-- Fills up as the review progresses.
local PROGRESS = { "󰪞", "󰪟", "󰪠", "󰪡", "󰪢", "󰪣", "󰪤" }
local EMPTY = "󰝦"
local ICON = ""

local buf, win
-- The file last opened.
local selected_repo_path
-- The panel's view before another buffer replaced it.
local saved_view
-- As last drawn.
local rows = {}

local window_options = {
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

function M.is_open()
    return win ~= nil and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf
end

-- Rows

local FOLDER = ""
local DONE = "󰄴"

-- How each file is shown, by path. Reset when the grouping depth changes.
local layouts, layouts_depth = {}, nil

local function layout(path)
    if layouts_depth ~= config.options.depth then
        layouts, layouts_depth = {}, config.options.depth
    end
    if not layouts[path] then
        local dirs = vim.split(vim.fs.dirname(path), "/", { plain = true })
        local name = vim.fn.fnamemodify(path, ":t")
        local icon, icon_hl = require("nvim-web-devicons").get_icon(name, nil, { default = true })
        layouts[path] = {
            dir = dirs[1] == "." and "" or table.concat(dirs, "/", 1, math.min(config.options.depth, #dirs)),
            text = icon .. " " .. name,
            icon_end = #icon,
            icon_hl = icon_hl,
        }
    end
    return layouts[path]
end

-- Pending files by directory, and the directories sorted.
local function group_by_dir(files)
    local by_dir, dirs = {}, {}
    for _, file in ipairs(files) do
        if file:needs_review() then
            local dir = layout(file.path).dir
            if not by_dir[dir] then
                by_dir[dir] = {}
                table.insert(dirs, dir)
            end
            table.insert(by_dir[dir], file)
        end
    end
    table.sort(dirs)
    return by_dir, dirs
end

-- "+added -removed" as chunks.
local function count_chunks(file)
    local chunks = {}
    local lines_added, lines_removed = file:counts_to_show()
    for _, count in ipairs({ { lines_added, "+", "ReviewPanelAdded" }, { lines_removed, "-", "ReviewPanelRemoved" } }) do
        local number, sign, group = count[1], count[2], count[3]
        if (number or 0) > 0 then
            table.insert(chunks, { sign .. number .. " ", group })
        end
    end
    return chunks
end

-- A row's extmarks as { col, opts }: icon highlight, dot, directory header, strikethrough and counts.
local function extmarks(file, text, header)
    local file_layout = layout(file.path)
    local dot = file:changed_after_review() and "ReviewChanged" or file:is_unseen() and "ReviewNew"
    local found = {
        {
            0,
            {
                end_col = file_layout.icon_end,
                hl_group = file_layout.icon_hl,
                virt_text = dot and { { " ●", dot } } or nil,
                virt_lines = header and { { { " " .. FOLDER .. (header ~= "" and " " .. header or ""), "ReviewPanelDir" } } } or nil,
                virt_lines_above = true,
                virt_lines_leftcol = true,
            },
        },
    }
    if file.is_deleted then
        table.insert(found, { file_layout.icon_end + 1, { end_col = #text, hl_group = "ReviewPanelDeleted" } })
    end
    local counts = count_chunks(file)
    if #counts > 0 then
        table.insert(found, { 0, { virt_text = counts, virt_text_pos = "right_align" } })
    end
    return found
end

-- Rows of files to review: { file, text, header, ends_group, extmarks }. Header is the directory, on a group's first.
local function build_rows(files)
    local by_dir, dirs = group_by_dir(files)
    local rows = {}
    for _, dir in ipairs(dirs) do
        for i, file in ipairs(by_dir[dir]) do
            table.insert(rows, { file = file, text = layout(file.path).text, header = i == 1 and dir or nil })
        end
        rows[#rows].ends_group = true
    end
    if config.options.view == "since_review" then
        session.count_lines_since_review(vim.tbl_map(function(row)
            return row.file
        end, rows))
    end
    for _, row in ipairs(rows) do
        row.extmarks = extmarks(row.file, row.text, row.header)
    end
    return rows
end

-- The done message as virtual lines, centered in the window.
local function done_lines(reviewed_count, width, height)
    local undo = config.options.keymaps.undo
    local message = { { DONE, "ReviewSignAdd" } }
    if reviewed_count == 0 then
        table.insert(message, { "Nothing to review", "Comment" })
    else
        table.insert(message, { "Review complete", "Normal" })
        table.insert(message, { ("%d file%s reviewed"):format(reviewed_count, reviewed_count == 1 and "" or "s"), "Comment" })
        if undo then
            vim.list_extend(message, { { "", "Comment" }, { undo .. " to undo", "Comment" } })
        end
    end
    -- The empty buffer line takes the first row.
    local lines = {}
    for _ = 1, math.floor((height - #message) / 2) - 1 do
        table.insert(lines, { { "", "Normal" } })
    end
    for _, chunk in ipairs(message) do
        local padding = math.max(math.floor((width - vim.fn.strdisplaywidth(chunk[1])) / 2), 0)
        -- Own chunk, so it does not get the text's background.
        table.insert(lines, { { string.rep(" ", padding), "Normal" }, chunk })
    end
    return lines
end

-- Drawing

-- Shows the first header, which is otherwise scrolled off.
local function show_top_header()
    vim.api.nvim_win_call(win, function()
        local view = vim.fn.winsaveview()
        if rows[1] and view.topline == 1 and view.topfill == 0 then
            vim.fn.winrestview({ topline = 1, topfill = 1 })
        end
    end)
end

local function show_done()
    vim.api.nvim_buf_clear_namespace(buf, done_namespace, 0, -1)
    if #rows == 0 then
        local lines = done_lines(#session.files, vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win))
        vim.api.nvim_buf_set_extmark(buf, done_namespace, 0, 0, { virt_lines = lines, virt_lines_leftcol = true })
    end
end

local function mark_selected()
    vim.api.nvim_buf_clear_namespace(buf, selected_namespace, 0, -1)
    for i, row in ipairs(rows) do
        if row.file.repo_path == selected_repo_path then
            vim.api.nvim_buf_set_extmark(buf, selected_namespace, i - 1, 0, { line_hl_group = "ReviewPanelLine" })
            return i
        end
    end
end

-- Cursor goes to the line, else the selected file, else the first row.
local function draw(cursor_line)
    rows = build_rows(session.files)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.tbl_map(function(row)
        return row.text
    end, rows))
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, rows_namespace, 0, -1)
    for i, row in ipairs(rows) do
        for _, mark in ipairs(row.extmarks) do
            vim.api.nvim_buf_set_extmark(buf, rows_namespace, i - 1, mark[1], mark[2])
        end
    end
    local selected_row = mark_selected()
    cursor_line = cursor_line or selected_row
    vim.api.nvim_win_set_cursor(win, { math.max(math.min(cursor_line or 1, #rows), 1), 0 })
    show_top_header()
    show_done()
    -- The winbar only redraws itself on window events.
    vim.cmd.redrawstatus({ bang = true })
end

-- Redraws, keeping the cursor.
function M.refresh()
    if M.is_open() then
        draw(vim.api.nvim_win_get_cursor(win)[1])
    end
end

-- Actions

local function mark_reviewed(first, last)
    local repo_paths = vim.tbl_map(function(row)
        return row.file.repo_path
    end, vim.list_slice(rows, first, last))
    if #repo_paths > 0 then
        session.review(repo_paths, first)
        render.review_changed(repo_paths)
        draw(first)
    end
end

local function undo_or_redo(step)
    local cursor_line, repo_paths = step(vim.fn.line("."))
    if cursor_line then
        render.review_changed(repo_paths)
        draw(cursor_line)
    end
end

-- The previous window, any other one, or a new one.
local function target_window()
    for _, candidate in ipairs({ vim.fn.win_getid(vim.fn.winnr("#")), unpack(vim.api.nvim_tabpage_list_wins(0)) }) do
        if candidate ~= 0 and candidate ~= win and vim.api.nvim_win_get_config(candidate).relative == "" then
            return candidate
        end
    end
    vim.cmd("botright vnew")
    return vim.api.nvim_get_current_win()
end

-- Opens the file at its first hunk, keeping focus in the panel.
local function open_file(file, target_win)
    vim.api.nvim_set_current_win(target_win)
    if file.is_deleted then
        vim.api.nvim_win_set_buf(target_win, deleted.open(file.path))
    else
        vim.cmd.edit(vim.fn.fnameescape(file.path))
        local first_hunk = render.first_hunk(vim.api.nvim_get_current_buf())
        if first_hunk then
            vim.api.nvim_win_set_cursor(0, { math.max(first_hunk.new_start, 1), 0 })
            vim.cmd("normal! zz")
            render.reveal(vim.api.nvim_get_current_buf())
        end
    end
    vim.api.nvim_set_current_win(win)
end

local function open_selected_row()
    local line = vim.fn.line(".")
    local file = rows[line] and rows[line].file
    if not file then
        return
    end
    -- Opening it clears its dot.
    local has_dot = file:changed_after_review() or file:is_unseen()
    if has_dot then
        session.mark_opened(file.repo_path)
    end
    local target = target_window()
    if deleted.path(vim.api.nvim_win_get_buf(target)) == vim.fn.fnamemodify(file.path, ":.") then
        return has_dot and draw(line)
    end
    selected_repo_path = file.repo_path
    if has_dot then
        draw(line)
    else
        mark_selected()
    end
    open_file(file, target)
end

function M.operator()
    mark_reviewed(vim.fn.line("'["), vim.fn.line("']"))
end

local function create_buffer()
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "review"
    local keymaps = config.options.keymaps
    local function map(mode, lhs, rhs, opts)
        if lhs then
            vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { buffer = buf }, opts or {}))
        end
    end
    vim.api.nvim_create_autocmd("CursorMoved", { buffer = buf, callback = show_top_header })
    -- To restore after another buffer replaces it.
    vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = buf,
        callback = function()
            saved_view = vim.api.nvim_get_current_win() == win and vim.fn.winsaveview() or saved_view
        end,
    })
    map("n", keymaps.open, open_selected_row)
    map("n", "<2-LeftMouse>", open_selected_row)
    map("n", keymaps.mark_reviewed, function()
        vim.o.operatorfunc = "v:lua.require'review.panel'.operator"
        return "g@"
    end, { expr = true })
    -- Doubled reviews the current line, like dd.
    map("o", keymaps.mark_reviewed, "_")
    map("x", keymaps.mark_reviewed, function()
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        vim.cmd("normal! \27")
        mark_reviewed(math.min(first, last), math.max(first, last))
    end)
    map("n", keymaps.undo, function()
        undo_or_redo(session.undo)
    end)
    map("n", keymaps.redo, function()
        undo_or_redo(session.redo)
    end)
end

-- Window

-- Below 1 is a ratio of the editor's width.
local function panel_width()
    local width = config.options.width
    return width < 1 and math.max(math.floor(vim.o.columns * width), 1) or width
end

-- Unless just loaded, shows the last load and schedules a reload.
function M.toggle(just_loaded)
    if M.is_open() then
        return M.close()
    end
    if not just_loaded then
        require("review.git").schedule_change()
    end
    session.load_progress()
    -- Selects the current file.
    local repo_path = session.cwd_prefix .. deleted.path(vim.api.nvim_get_current_buf())
    if session.by_repo_path[repo_path] then
        selected_repo_path = repo_path
    end
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        create_buffer()
    end
    vim.cmd("topleft vertical " .. panel_width() .. "split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    for option, value in pairs(window_options) do
        vim.wo[win][0][option] = value
    end
    draw()
end

function M.close()
    if M.is_open() then
        pcall(vim.api.nvim_win_close, win, false)
    end
end

-- Moves a buffer opened in the panel, like with :edit, to the previous window and focuses it.
function M.guard()
    if not (win and vim.api.nvim_win_is_valid(win) and buf and vim.api.nvim_buf_is_valid(buf)) then
        return
    end
    local opened_buf = vim.api.nvim_win_get_buf(win)
    if opened_buf == buf then
        return
    end
    local cursor_pos = vim.api.nvim_win_get_cursor(win)
    local target = target_window()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(saved_view or {})
    end)
    vim.api.nvim_win_set_buf(target, opened_buf)
    vim.api.nvim_win_set_cursor(target, cursor_pos)
    vim.api.nvim_set_current_win(target)
end

function M.follow(entered_buf)
    local repo_path = session.cwd_prefix .. deleted.path(entered_buf)
    if repo_path ~= selected_repo_path and session.by_repo_path[repo_path] then
        selected_repo_path = repo_path
        if M.is_open() then
            mark_selected()
        end
    end
end

-- Keeps a ratio width after the editor resizes.
function M.fit()
    if M.is_open() and config.options.width < 1 then
        vim.api.nvim_win_set_width(win, panel_width())
    end
end

function M.resized()
    if M.is_open() and vim.tbl_contains(vim.v.event.windows, win) then
        show_done()
    end
end

-- Restores panel options changed by :set while in it.
function M.option_set()
    local option = vim.fn.expand("<amatch>")
    if window_options[option] ~= nil and M.is_open() and vim.api.nvim_get_current_win() == win then
        vim.wo[win][0][option] = window_options[option]
    end
end

-- Columns

-- The branches and the progress %.
function M.winbar()
    local remaining_weight = 0
    for _, row in ipairs(rows) do
        remaining_weight = remaining_weight + row.file.progress_weight
    end
    local total_weight = session.total_progress_weight
    -- 100% only once no files are left.
    local done = #rows == 0
    local percent = done and 100 or total_weight > 0 and math.min(math.floor((total_weight - remaining_weight) / total_weight * 100), 99) or 0
    local icon = done and DONE or percent == 0 and EMPTY or PROGRESS[math.max(math.ceil(percent * #PROGRESS / 100), 1)]
    local progress = ("%d%%%% %s"):format(percent, icon)
    local branches = ("%s  %s"):format(session.branch, session.base_ref)
    if vim.fn.strdisplaywidth(branches .. progress) + 7 > vim.api.nvim_win_get_width(0) then
        branches = " " .. session.base_ref
    end
    return branches .. "%=" .. progress .. " "
end

-- The tree in the number column.
function M.number()
    local row = rows[vim.v.lnum]
    if not row then
        return ""
    end
    return (row.file.repo_path == selected_repo_path and "%#ReviewPanelNr#" or "") .. (row.ends_group and "└─" or "├─")
end

return M
