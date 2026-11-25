local T = {}

-- Types the keys in the main loop and waits until they ran.
local function press(keys)
    local co = coroutine.running()
    vim.api.nvim_input(keys)
    vim.defer_fn(function()
        coroutine.resume(co)
    end, 50)
    coroutine.yield()
end

-- A file in a directory, with three lines.
local function edit(path)
    path = vim.fn.tempname() .. "/" .. (path or "dir/file.lua")
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile({ "a", "b", "c" }, path)
    vim.cmd.edit(vim.fn.fnameescape(path))
end

function T.a_file_shows_its_icon_and_directory()
    edit()
    assert(vim.wo.winbar == "  <lua> dir/file.lua", vim.wo.winbar)
end

-- Opened with the options of the window it opened from, which for the winbar is cleared to see it is left alone.
function T.floating_windows_are_left_alone()
    edit()
    local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, { relative = "editor", row = 1, col = 1, width = 20, height = 3 })
    vim.wo[float].winbar = ""
    require("winbar").set_winbar()
    local winbar = vim.wo[float].winbar
    vim.api.nvim_win_close(float, true)
    assert(winbar == "", winbar)
end

function T.an_edit_marks_the_file_modified_until_undone()
    edit()
    press("dd")
    local edited = vim.wo.winbar
    press("<Cmd>silent undo<CR>")
    assert(edited == "  <lua> dir/file.lua ●", edited)
    assert(vim.wo.winbar == "  <lua> dir/file.lua", vim.wo.winbar)
end

function T.writing_clears_the_modified_mark()
    edit()
    press("dd")
    vim.cmd("silent write")
    assert(vim.wo.winbar == "  <lua> dir/file.lua", vim.wo.winbar)
end

function T.an_unnamed_buffer_has_no_name()
    vim.cmd.enew()
    vim.cmd.doautocmd("BufWinEnter")
    assert(vim.wo.winbar:match("%[No Name%]$"), vim.wo.winbar)
end

function T.a_readonly_buffer_shows_a_lock()
    edit()
    vim.bo.readonly = true
    vim.cmd.doautocmd("BufWinEnter")
    local lock = require("winbar").get_winbar():match("dir/file.lua(.+)$")
    assert(lock and not lock:find("●"), vim.wo.winbar)
end

function T.a_built_in_bar_shows_by_filetype()
    vim.cmd("copen")
    local bar = require("winbar.config").options.bars.qf
    local winbar = vim.wo.winbar
    vim.cmd("cclose")
    assert(winbar:find(bar.icon .. " QuickFix", 1, true), winbar)
end

function T.excluded_filetypes_keep_their_own_winbar()
    vim.cmd.enew()
    vim.wo.winbar = "own"
    vim.bo.filetype = "excluded"
    vim.cmd.doautocmd("BufWinEnter")
    press("ix<Esc>")
    assert(vim.wo.winbar == "own", vim.wo.winbar)
end

return T
