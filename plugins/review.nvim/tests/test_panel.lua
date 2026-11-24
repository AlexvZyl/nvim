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

function T.deleted_files_show_struck_through_and_open_as_deleted_lines()
    setup()
    require("review").stop()
    vim.cmd("silent! only | enew | silent! %bwipeout!")
    vim.system({ "git", "rm", "-q", "file.txt" }):wait()
    vim.system({ "git", "commit", "-qm", "delete" }):wait()
    local main = vim.api.nvim_get_current_win()
    require("review").start("dev")
    local panel_buf = vim.api.nvim_get_current_buf()
    local row = vim.fn.search("file.txt$")
    assert(row > 0, "deleted file not listed")
    local struck = vim.iter(h.marks(panel_buf, "review_panel", row, row + 1)):any(function(mark)
        return mark[4].hl_group == "ReviewPanelDeleted"
    end)
    assert(struck, "not struck through")
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    local opened = vim.api.nvim_win_get_buf(main)
    assert(vim.api.nvim_buf_get_name(opened) == "review://file.txt", vim.api.nvim_buf_get_name(opened))
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(opened, 0, -1, false), h.lines(5)), "not the old contents")
    assert(not vim.bo[opened].modifiable, "modifiable")
    local marks = h.marks(opened, "review", 1, 6)
    assert(#marks == 5 and marks[1][4].line_hl_group == "ReviewDelete", vim.inspect(marks))
    teardown()
end

return T
