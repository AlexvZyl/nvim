local h = require("tests.helpers")

local T = {}

package.preload["nvim-web-devicons"] = function()
    return {
        get_icon = function()
            return "", "Normal"
        end,
    }
end

-- The panel open and focused over the file, with 80 changed files so it scrolls.
local function setup()
    local files = {}
    for i = 1, 80 do
        files["f" .. i .. ".txt"] = true
    end
    h.repo(h.lines(5), h.lines(6))
    for name in pairs(files) do
        vim.fn.writefile({ "a" }, name)
    end
    vim.system({ "git", "add", "." }):wait()
    vim.system({ "git", "commit", "-qm", "files" }):wait()
    vim.fn.writefile({ "a", "b", "c", "d", "e" }, "other.txt")
    vim.o.lines = 40
    vim.o.columns = 200
    vim.cmd("silent! %bwipeout!")
    vim.cmd.edit("file.txt")
    local main = vim.api.nvim_get_current_win()
    require("review").start("dev")
    return main, vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
end

local function teardown()
    require("review").stop()
end

local function check(main, panel, panel_buf, name, line)
    assert(vim.api.nvim_win_get_buf(panel) == panel_buf, "panel lost its buffer")
    assert(vim.api.nvim_get_current_win() == main, "focus not on the previous window")
    local opened = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(main)), ":t")
    assert(opened == name, opened)
    assert(vim.api.nvim_win_get_cursor(main)[1] == line, vim.inspect(vim.api.nvim_win_get_cursor(main)))
end

function T.editing_from_the_panel_opens_in_the_previous_window()
    local main, panel, panel_buf = setup()
    vim.cmd("edit +4 other.txt")
    check(main, panel, panel_buf, "other.txt", 4)
    vim.api.nvim_set_current_win(panel)
    vim.cmd("buffer file.txt")
    check(main, panel, panel_buf, "file.txt", 1)
    teardown()
end

-- Like a picker: the file is not loaded yet, and the cursor is set in the current window after.
function T.picking_a_file_from_the_panel_opens_in_the_previous_window()
    local main, panel, panel_buf = setup()
    vim.cmd("edit other.txt")
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    check(main, panel, panel_buf, "other.txt", 3)
    teardown()
end

function T.opening_from_the_panel_keeps_its_scroll()
    local _, panel = setup()
    vim.cmd("normal! 50Gzt5j")
    vim.cmd("redraw")
    local before = vim.api.nvim_win_call(panel, vim.fn.winsaveview)
    vim.cmd("edit other.txt")
    vim.cmd("redraw")
    local after = vim.api.nvim_win_call(panel, vim.fn.winsaveview)
    assert(before.topline == after.topline and before.lnum == after.lnum, vim.inspect({ before, after }))
    teardown()
end

return T
