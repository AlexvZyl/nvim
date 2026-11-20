local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local buffer_hunks = {}
local quickfix_undo = {}
local quickfix_redo = {}
local SIGN = "│"
local QUICKFIX_WIDTH = 60
local QUICKFIX_TITLE = "review"
local MARK = "●"
local QUICKFIX_TEXT_FUNC = "v:lua.require'alex.native.review'.quickfix_text"

M.changed = {}
M.new = {}
M.seen = {}
M.reviewed = {}

local function git(...)
    local cmd = { "git", "-C", vim.fn.getcwd(), ... }
    local result = vim.system(cmd, { text = true }):wait()
    return result.code == 0 and result.stdout or nil
end

local function git_diff(...)
    return git("diff", "--merge-base", M.ref, ...)
end

local function parse_hunks(patch)
    local hunks = {}
    local current
    for _, line in ipairs(vim.split(patch, "\n", { plain = true })) do
        local start, count = line:match("^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
        if start then
            current = {
                start = tonumber(start),
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

local function deleted_virt_lines(buf, deleted)
    local tab = string.rep(" ", vim.bo[buf].tabstop)
    local win = vim.fn.win_findbuf(buf)[1] or vim.api.nvim_get_current_win()
    local textoff = vim.fn.getwininfo(win)[1].textoff
    local gutter = " " .. SIGN .. string.rep(" ", textoff - 2)
    local virt_lines = {}
    for _, text in ipairs(deleted) do
        text = text:gsub("\t", tab)
        local padded = text .. string.rep(" ", math.max(vim.o.columns - #text, 0))
        table.insert(virt_lines, { { gutter, "ReviewSignDelete" }, { padded, "ReviewDelete" } })
    end
    return virt_lines
end

local function render(buf, hunks, local_hunks)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    local local_lines = {}
    for _, hunk in ipairs(local_hunks) do
        local last = math.max(hunk.start + hunk.count - 1, hunk.start)
        for line = math.max(hunk.start, 1), last do
            local_lines[line] = true
            vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                sign_text = SIGN,
                sign_hl_group = "ReviewSignLocal",
            })
        end
    end
    for _, hunk in ipairs(hunks) do
        for line = hunk.start, hunk.start + hunk.count - 1 do
            if not local_lines[line] then
                vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                    line_hl_group = "ReviewAdd",
                    sign_text = SIGN,
                    sign_hl_group = "ReviewSignAdd",
                })
            end
        end
        if #hunk.deleted > 0 then
            vim.api.nvim_buf_set_extmark(buf, namespace, math.max(hunk.start - 1, 0), 0, {
                virt_lines = deleted_virt_lines(buf, hunk.deleted),
                virt_lines_above = hunk.count > 0 or hunk.start == 0,
                virt_lines_leftcol = true,
            })
        end
    end
end

local function jump(hunks, forward)
    local current = vim.api.nvim_win_get_cursor(0)[1]
    local target
    for _, hunk in ipairs(hunks) do
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

local function attach(buf)
    local file = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= "" or vim.fn.filereadable(file) == 0 then
        return
    end
    local patch = git_diff("-U0", "--", file)
    if not patch then
        return
    end
    local hunks = parse_hunks(patch)
    buffer_hunks[buf] = hunks
    local local_hunks = parse_hunks(git("diff", "-U0", "HEAD", "--", file) or "")
    vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then
            return
        end
        render(buf, hunks, local_hunks)
    end)
    vim.keymap.set("n", "]h", function()
        jump(hunks, true)
    end, { buffer = buf })
    vim.keymap.set("n", "[h", function()
        jump(hunks, false)
    end, { buffer = buf })
end

local function load_files()
    local numstat = git_diff("--numstat", "--relative", "--diff-filter=d", "--no-renames")
    if not numstat then
        vim.notify("git diff " .. M.ref .. " failed", vim.log.levels.ERROR)
        return false
    end
    M.changed_files = {}
    M.file_changes = {}
    M.total_changes = 0
    for _, line in ipairs(vim.split(numstat, "\n", { trimempty = true })) do
        local added, deleted, path = line:match("^(%S+)\t(%S+)\t(.+)$")
        local changes = (tonumber(added) or 0) + (tonumber(deleted) or 0)
        table.insert(M.changed_files, path)
        M.file_changes[path] = changes
        M.total_changes = M.total_changes + changes
    end
    M.source = vim.trim(git("rev-parse", "--abbrev-ref", "HEAD") or "HEAD")
    return true
end

local function head_blobs()
    local blobs = {}
    for _, line in ipairs(vim.split(git("ls-tree", "-r", "HEAD") or "", "\n", { trimempty = true })) do
        local sha, path = line:match("^%S+ blob (%S+)\t(.+)$")
        if sha then
            blobs[path] = sha
        end
    end
    return blobs
end

local function state_path()
    local git_dir = vim.trim(git("rev-parse", "--absolute-git-dir") or "")
    local name = (M.source .. ".." .. M.ref):gsub("/", "%%")
    return git_dir .. "/review/" .. name .. ".json"
end

local function load_state()
    local ok, lines = pcall(vim.fn.readfile, state_path())
    local decoded, state = pcall(vim.json.decode, ok and table.concat(lines, "\n") or "")
    state = decoded and type(state) == "table" and state or {}
    M.reviewed = type(state.reviewed) == "table" and state.reviewed or {}
    M.seen = {}
    for _, path in ipairs(type(state.seen) == "table" and state.seen or M.changed_files) do
        M.seen[path] = true
    end
    quickfix_undo = type(state.undo) == "table" and state.undo or {}
    quickfix_redo = type(state.redo) == "table" and state.redo or {}
end

local function as_dict(reviewed)
    return next(reviewed) and reviewed or vim.empty_dict()
end

local function as_snapshots(stack)
    return vim.tbl_map(function(snapshot)
        return { reviewed = as_dict(snapshot.reviewed), cursor = snapshot.cursor }
    end, stack)
end

local function save_state()
    local path = state_path()
    local state = {
        reviewed = as_dict(M.reviewed),
        seen = vim.tbl_keys(M.seen),
        undo = as_snapshots(quickfix_undo),
        redo = as_snapshots(quickfix_redo),
    }
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({ vim.json.encode(state) }, path .. ".tmp")
    vim.uv.fs_rename(path .. ".tmp", path)
end

local function build_items()
    M.changed = {}
    M.new = {}
    local items = {}
    for _, path in ipairs(M.changed_files) do
        local reviewed = M.reviewed[path]
        if reviewed ~= M.blobs[path] then
            M.changed[path] = reviewed ~= nil
            M.new[path] = not M.seen[path]
            table.insert(items, { filename = path, lnum = 1, col = 1, text = "", user_data = path })
        end
    end
    return items
end

local function mark_text(path)
    if M.changed[path] then
        return { { " " .. MARK, "ReviewChanged" } }
    end
    if M.new[path] then
        return { { " " .. MARK, "ReviewNew" } }
    end
end

local function highlight_quickfix_icons(buf)
    local devicons = require("nvim-web-devicons")
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

local function refresh_quickfix(cursor)
    local items = build_items()
    local idx = vim.fn.getqflist({ idx = 0 }).idx
    vim.fn.setqflist({}, "r", {
        items = items,
        title = QUICKFIX_TITLE,
        quickfixtextfunc = QUICKFIX_TEXT_FUNC,
        idx = math.max(math.min(idx, #items), 1),
    })
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    highlight_quickfix_icons(buf)
    vim.api.nvim_win_set_cursor(0, { math.max(math.min(cursor, #items), 1), 0 })
end

local function snapshot(cursor)
    return { reviewed = vim.deepcopy(M.reviewed), cursor = cursor }
end

local function remove_quickfix_items(first, last)
    local list = vim.fn.getqflist({ title = 0, items = 0 })
    if list.title ~= QUICKFIX_TITLE then
        return
    end
    table.insert(quickfix_undo, snapshot(first))
    quickfix_redo = {}
    for i = first, last do
        local path = list.items[i].user_data
        M.reviewed[path] = M.blobs[path]
        M.seen[path] = true
    end
    save_state()
    refresh_quickfix(first)
end

local function restore_quickfix(from, to)
    if vim.fn.getqflist({ title = 0 }).title ~= QUICKFIX_TITLE then
        return
    end
    local state = table.remove(from)
    if state then
        table.insert(to, snapshot(vim.fn.line(".")))
        M.reviewed = state.reviewed
        save_state()
        refresh_quickfix(state.cursor)
    end
end

local function open_quickfix()
    vim.cmd("topleft vertical copen " .. QUICKFIX_WIDTH)
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    highlight_quickfix_icons(buf)
    vim.wo.relativenumber = false
    vim.wo.winhighlight = "QuickFixLine:ReviewQuickFixLine,qfFileName:Normal"
    vim.wo.cursorline = false
    vim.wo.statuscolumn =
        " %s%=%{%v:lua.require'alex.native.review'.quickfix_number()%}%#WinSeparator#  "
    local function select()
        local line = vim.fn.line(".")
        local item = vim.fn.getqflist()[line]
        if item and (M.changed[item.user_data] or M.new[item.user_data]) then
            M.reviewed[item.user_data] = nil
            M.seen[item.user_data] = true
            save_state()
            refresh_quickfix(line)
        end
        vim.cmd(line .. "cc")
        if vim.fn.getqflist({ title = 0 }).title ~= QUICKFIX_TITLE then
            return
        end
        local first = (buffer_hunks[vim.api.nvim_get_current_buf()] or {})[1]
        if first then
            vim.api.nvim_win_set_cursor(0, { math.max(first.start, 1), 0 })
            vim.cmd("normal! zz")
        end
        vim.cmd("wincmd p")
    end
    vim.keymap.set("n", "<CR>", select, { buffer = buf })
    vim.keymap.set("n", "<2-LeftMouse>", select, { buffer = buf })
    vim.keymap.set("n", "dd", function()
        local line = vim.fn.line(".")
        remove_quickfix_items(line, line)
    end, { buffer = buf })
    vim.keymap.set("n", "u", function()
        restore_quickfix(quickfix_undo, quickfix_redo)
    end, { buffer = buf })
    vim.keymap.set("n", "<C-r>", function()
        restore_quickfix(quickfix_redo, quickfix_undo)
    end, { buffer = buf })
    vim.keymap.set("x", "d", function()
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        vim.cmd("normal! \27")
        remove_quickfix_items(math.min(first, last), math.max(first, last))
    end, { buffer = buf })
end

local function panel_window()
    for _, info in ipairs(vim.fn.getwininfo()) do
        if info.tabnr == vim.fn.tabpagenr() and info.quickfix == 1 and info.loclist == 0 then
            return info.winid
        end
    end
end

function M.panel()
    if not M.ref then
        return vim.notify("Not in diff mode", vim.log.levels.WARN)
    end
    if panel_window() and vim.fn.getqflist({ title = 0 }).title == QUICKFIX_TITLE then
        return vim.cmd("cclose")
    end
    if not load_files() then
        return
    end
    M.blobs = head_blobs()
    load_state()
    vim.fn.setqflist({}, " ", {
        items = build_items(),
        title = QUICKFIX_TITLE,
        quickfixtextfunc = QUICKFIX_TEXT_FUNC,
    })
    open_quickfix()
end

function M.reset()
    if not M.ref then
        return vim.notify("Not in diff mode", vim.log.levels.WARN)
    end
    if not load_files() then
        return
    end
    os.remove(state_path())
    M.reviewed = {}
    quickfix_undo = {}
    quickfix_redo = {}
    if panel_window() and vim.fn.getqflist({ title = 0 }).title == QUICKFIX_TITLE then
        vim.cmd("cclose")
        M.panel()
    end
end

function M.quickfix_winbar()
    if vim.fn.getqflist({ title = 0 }).title ~= QUICKFIX_TITLE then
        return nil
    end
    local remaining = 0
    for _, item in ipairs(vim.fn.getqflist()) do
        remaining = remaining + (M.file_changes[item.user_data] or 0)
    end
    local percent = M.total_changes > 0 and math.floor(remaining / M.total_changes * 100 + 0.5) or 0
    local metrics = string.format(" %d%%", percent)
    local branches = string.format("%s  %s", M.source, M.ref)
    if vim.fn.strdisplaywidth(branches .. metrics) + 7 > vim.api.nvim_win_get_width(0) then
        branches = " " .. M.ref
    end
    return branches .. "%=" .. metrics:gsub("%%", "%%%%") .. " "
end

function M.quickfix_number()
    local selected = vim.v.lnum == vim.fn.getqflist({ idx = 0 }).idx
    return (selected and "%#ReviewQuickFixNr#" or "") .. vim.v.lnum
end

function M.quickfix_text(info)
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

function M.files()
    if not M.ref then
        return vim.notify("Not in diff mode", vim.log.levels.WARN)
    end
    if not load_files() then
        return
    end
    require("telescope")
    local templates = require("alex.plugins.telescope")
    local make_entry = require("telescope.make_entry").gen_from_file({})
    require("telescope.pickers")
        .new(vim.tbl_extend("force", templates.large_no_preview, { prompt_title = "Review files" }), {
            finder = require("telescope.finders").new_table({
                results = M.changed_files,
                entry_maker = function(line)
                    local entry = make_entry(line)
                    entry.text = ""
                    return entry
                end,
            }),
            sorter = require("telescope.config").values.generic_sorter({}),
        })
        :find()
end

if vim.fn.argv(0) == "diff" then
    M.ref = vim.fn.argc() > 1 and vim.fn.argv(1) or "dev"
    vim.cmd("%argdelete")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= vim.api.nvim_get_current_buf() then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
    vim.api.nvim_buf_set_name(0, "")

    vim.api.nvim_create_user_command("ReviewReset", M.reset, {})
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        callback = function(args)
            attach(args.buf)
        end,
    })
end

return M
