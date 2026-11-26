local h = require("tests.helpers")

local T = {}

-- The panel open and focused over the file, with 80 changed files so it scrolls.
local function setup()
    h.repo(h.lines(5), h.lines(6))
    local files = {}
    for i = 1, 80 do
        files["f" .. i .. ".txt"] = { "a" }
    end
    h.commit(files)
    h.write("other.txt", { "a", "b", "c", "d", "e" })
    vim.o.lines = 40
    vim.o.columns = 200
    vim.cmd("silent! %bwipeout!")
    vim.cmd.edit("file.txt")
    local main = vim.api.nvim_get_current_win()
    h.start()
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

-- With no saved state nothing is new, and the first group's directory shows above it.
function T.the_width_is_in_columns_or_a_ratio_kept_as_the_editor_resizes()
    local options = require("review.config").options
    local _, panel = setup()
    local columns = vim.api.nvim_win_get_width(panel)
    teardown()
    options.width = 0.25
    local _, ratio = setup()
    local quarter = vim.api.nvim_win_get_width(ratio)
    vim.o.columns = 100
    vim.api.nvim_exec_autocmds("VimResized", {})
    local resized = vim.api.nvim_win_get_width(ratio)
    options.width = 60
    teardown()
    assert(columns == 60 and quarter == 50 and resized == 25, vim.inspect({ columns, quarter, resized }))
end

function T.the_panel_opens_on_the_file_it_is_opened_from()
    local main = setup()
    local started = vim.api.nvim_get_current_line()
    vim.api.nvim_set_current_win(main)
    vim.cmd.edit("f50.txt")
    require("review").panel()
    require("review").panel()
    local reopened = vim.api.nvim_get_current_line()
    vim.cmd.enew()
    require("review").panel()
    require("review").panel()
    local unchanged = vim.api.nvim_get_current_line()
    teardown()
    assert(started:match(" file.txt$") and reopened:match(" f50.txt$") and unchanged == reopened, vim.inspect({ started, reopened, unchanged }))
end

-- Like a file removed by another program while the panel was closed, which leaves the review as the branch added it.
function T.reopening_the_panel_shows_what_changed_while_closed()
    local _, _, panel_buf = setup()
    local function listed()
        return vim.tbl_contains(vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false), " f1.txt")
    end
    local before = listed()
    require("review").panel()
    os.remove("f1.txt")
    require("review").panel()
    local gone = vim.wait(1000, function()
        return not listed()
    end)
    teardown()
    assert(before and gone, vim.inspect({ before, gone }))
end

function T.a_first_review_lists_the_files_as_a_tree()
    local _, panel, panel_buf = setup()
    local dots = vim.tbl_filter(function(mark)
        return mark[4].virt_text and mark[4].virt_text[1][2] == "ReviewNew"
    end, h.marks(panel_buf, "review_panel", 1, vim.api.nvim_buf_line_count(panel_buf)))
    -- Opened on file.txt, further down.
    vim.api.nvim_win_set_cursor(panel, { 1, 0 })
    require("review.panel").refresh()
    local topfill = vim.api.nvim_win_call(panel, vim.fn.winsaveview).topfill
    local function branch(row)
        vim.api.nvim_win_set_cursor(panel, { row, 0 })
        return vim.api.nvim_eval_statusline(vim.wo[panel].statuscolumn, { winid = panel, use_statuscol_lnum = row }).str
    end
    local first, last = branch(1), branch(vim.api.nvim_buf_line_count(panel_buf))
    teardown()
    assert(#dots == 0, vim.inspect(dots))
    assert(topfill == 1, topfill)
    assert(first:find("├─", 1, true) and last:find("└─", 1, true), vim.inspect({ first, last }))
end

-- Like a toggle of relative numbers in the config, which sets them for every window with :set.
function T.setting_line_numbers_keeps_the_branches()
    local _, panel = setup()
    vim.o.relativenumber = true
    vim.o.statuscolumn = "%{v:relnum?v:relnum:v:lnum}"
    local shown = vim.api.nvim_eval_statusline(vim.wo[panel].statuscolumn, { winid = panel, use_statuscol_lnum = 1 }).str
    local relative = vim.wo[panel].relativenumber
    vim.o.relativenumber, vim.o.statuscolumn = false, ""
    teardown()
    assert(shown:find("├─", 1, true) and not relative, vim.inspect({ shown, relative }))
end

function T.reviewing_files_hides_them_until_undone()
    local _, _, panel_buf = setup()
    local function names()
        return vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
    end
    local all = #names()
    h.press("ggdd")
    local after_dd = #names()
    h.press("Vjd")
    local after_visual = #names()
    h.press("u")
    local after_undo = #names()
    h.press("<C-r>")
    local after_redo = #names()
    -- Reviewing more after an undo leaves nothing to redo.
    h.press("uggdd<C-r>")
    local redo_cleared = #names()
    h.press("ggdG")
    local done = h.marks(panel_buf, "review_panel_done", 1, 1)
    local winbar = require("review.panel").winbar()
    teardown()
    assert(after_dd == all - 1 and after_visual == all - 3, vim.inspect({ all, after_dd, after_visual }))
    assert(after_undo == all - 1 and after_redo == all - 3, vim.inspect({ after_undo, after_redo }))
    assert(redo_cleared == all - 2, vim.inspect({ all, redo_cleared }))
    assert(#done == 1 and winbar:find("100%%"), vim.inspect({ done, winbar }))
end

function T.resetting_forgets_the_reviewed_files()
    local _, _, panel_buf = setup()
    local all = vim.api.nvim_buf_line_count(panel_buf)
    h.press("ggdj")
    local reviewed = vim.api.nvim_buf_line_count(panel_buf)
    vim.cmd("ReviewReset")
    local reset = vim.api.nvim_buf_line_count(panel_buf)
    teardown()
    h.review()
    local reloaded = vim.api.nvim_buf_line_count(vim.api.nvim_get_current_buf())
    teardown()
    assert(reviewed == all - 2 and reset == all and reloaded == all, vim.inspect({ all, reviewed, reset, reloaded }))
end

-- From a directory in the repo, only the files under it, by their path from there.
function T.reviewing_from_a_directory_lists_the_files_under_it()
    local root = h.repo(h.lines(5), h.lines(6))
    h.commit({ ["sub/inner.txt"] = { "a" } })
    vim.cmd.cd("sub")
    local main, panel, panel_buf = h.review()
    local listed = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
    vim.fn.cursor(1, 1)
    h.press("<CR>")
    local opened = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(main))
    vim.api.nvim_set_current_win(panel)
    h.press("dd")
    local reviewed = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
    local saved = vim.fn.readfile(root .. "/.git/review/branch..dev.json")[1]
    teardown()
    vim.cmd.cd(root)
    assert(#listed == 1 and listed[1]:match("inner.txt$"), vim.inspect(listed))
    assert(opened == vim.fs.normalize(root .. "/sub/inner.txt"), opened)
    assert(vim.deep_equal(reviewed, { "" }) and saved:find('"sub/inner.txt"', 1, true), vim.inspect({ reviewed, saved }))
end

-- Grouped by their first two directories, with any characters in their names.
function T.files_are_grouped_by_directory_whatever_their_names()
    h.repo(h.lines(5), h.lines(5))
    h.commit({ ["a/b/c/with space.txt"] = { "x" }, ["é.txt"] = { "x" } })
    local main, _, panel_buf = h.review()
    local listed = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
    local headers = vim.tbl_map(function(mark)
        return vim.trim(mark[4].virt_lines[1][1][1])
    end, vim.tbl_filter(function(mark)
        return mark[4].virt_lines ~= nil
    end, h.marks(panel_buf, "review_panel", 1, #listed)))
    h.pick("with space.txt")
    local opened = vim.api.nvim_win_get_buf(main)
    local name, lines = vim.api.nvim_buf_get_name(opened), vim.api.nvim_buf_get_lines(opened, 0, -1, false)
    local signed = #h.marks(opened, "review", 1, 1)
    teardown()
    assert(#listed == 2 and listed[1]:match("é.txt$") and listed[2]:match("with space.txt$"), vim.inspect(listed))
    assert(#headers == 2 and not headers[1]:find("%w") and headers[2]:match(" a/b$"), vim.inspect(headers))
    assert(name:match("a/b/c/with space.txt$") and lines[1] == "x" and signed == 1, vim.inspect({ name, lines, signed }))
end

-- Right aligned, what each file added in green and removed in red, and nothing for a binary file.
function T.files_show_the_lines_they_added_and_removed()
    h.repo(h.lines(5), h.edit(h.lines(5), { [2] = "mod 2", [4] = false }))
    h.commit({ ["added.txt"] = { "a", "b", "c" }, ["binary.bin"] = "a\0b" })
    local _, _, panel_buf = h.review()
    local function counts(name)
        local row = vim.fn.search(name .. "$")
        for _, mark in ipairs(h.marks(panel_buf, "review_panel", row, row)) do
            if mark[4].virt_text_pos == "right_align" then
                return mark[4].virt_text
            end
        end
    end
    local file, added, binary = counts("file.txt"), counts("added.txt"), counts("binary.bin")
    -- A binary file left has no lines, but counts as one, not reviewed yet.
    for _, name in ipairs({ "file.txt", "added.txt" }) do
        vim.fn.cursor(vim.fn.search(name .. "$"), 1)
        h.press("dd")
    end
    local percent = require("review.panel").winbar():match("(%d+)%%%%")
    teardown()
    assert(percent == "85", percent)
    assert(vim.deep_equal(file, { { "+1 ", "ReviewPanelAdded" }, { "-2 ", "ReviewPanelRemoved" } }), vim.inspect(file))
    assert(vim.deep_equal(added, { { "+3 ", "ReviewPanelAdded" } }), vim.inspect(added))
    assert(binary == nil, vim.inspect(binary))
end

-- Progress counts changed lines, committed or not, so a small file left is a little of the review.
function T.progress_counts_the_lines_reviewed()
    h.repo(h.lines(5), h.lines(6))
    h.commit({ ["other.txt"] = { "a", "b", "c" } })
    h.write("file.txt", h.lines(8))
    h.review()
    local panel = require("review.panel")
    local function percent()
        return panel.winbar():match("(%d+)%%%%")
    end
    local before = percent()
    vim.fn.cursor(vim.fn.search("other.txt$"), 1)
    h.press("dd")
    local after = percent()
    teardown()
    assert(before == "0" and after == "50", vim.inspect({ before, after }))
end

-- Else the bar jumps from 0 to 100 at the last one.
function T.progress_counts_files_only_changed_locally()
    h.repo(h.lines(5), h.lines(5))
    h.git("checkout", "-q", "dev")
    h.commit({ ["other.txt"] = { "a" }, ["more.txt"] = { "a" } })
    h.git("checkout", "-q", "branch")
    h.git("merge", "-q", "--no-edit", "dev")
    for _, name in ipairs({ "file.txt", "other.txt", "more.txt" }) do
        h.write(name, name == "file.txt" and h.edit(h.lines(5), { [2] = "changed" }) or { "changed" })
    end
    h.review()
    local panel = require("review.panel")
    local function percent()
        return panel.winbar():match("(%d+)%%%%")
    end
    local before = percent()
    h.press("ggdd")
    local after = percent()
    teardown()
    assert(before == "0" and after == "33", vim.inspect({ before, after }))
end

function T.an_empty_review_is_done()
    h.repo(h.lines(5), h.lines(5))
    local _, _, panel_buf = h.review()
    local message = h.marks(panel_buf, "review_panel_done", 1, 1)[1][4].virt_lines
    local winbar = require("review.panel").winbar()
    teardown()
    assert(message[#message][2][1] == "Nothing to review" and winbar:find("100%%"), vim.inspect({ message, winbar }))
end

-- Alone, the panel opens files in a new window next to it.
function T.opening_from_a_lone_panel_opens_a_window()
    h.repo(h.lines(5), h.lines(6))
    local _, panel, panel_buf = h.review()
    vim.cmd("only")
    h.press("<CR>")
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local other = wins[1] == panel and wins[2] or wins[1]
    local opened = other and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(other))
    local kept = vim.api.nvim_win_get_buf(panel) == panel_buf
    teardown()
    assert(#wins == 2 and kept and opened:match("file.txt$"), vim.inspect({ wins, kept, opened }))
end

-- What the saved state has of use is kept, the rest ignored, and an emptied state saves and loads again.
function T.broken_saved_state_loads_what_it_can()
    h.repo(h.lines(5), h.lines(6))
    vim.fn.mkdir(".git/review", "p")
    local saved = {
        "not json",
        "5",
        '{"reviewed": 5, "seen": "x", "undo": [1, {"changes": {}}, {"changes": {"file.txt": {"reviewed": "x", "seen": true}}}]}',
    }
    for _, text in ipairs(saved) do
        vim.fn.writefile({ text }, ".git/review/branch..dev.json")
        local _, _, panel_buf = h.review()
        local listed = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
        vim.v.errmsg = ""
        -- Errors in mappings only show as messages.
        vim.cmd("silent! normal uuuddu")
        assert(vim.v.errmsg == "", text .. ": " .. vim.v.errmsg)
        local undone = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
        teardown()
        _, _, panel_buf = h.review()
        local reloaded = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
        teardown()
        assert(#listed == 1 and vim.deep_equal(listed, undone) and vim.deep_equal(listed, reloaded), vim.inspect({ text, listed, undone, reloaded }))
    end
end

function T.deleted_files_show_struck_through_and_open_as_deleted_lines()
    setup()
    require("review").stop()
    h.git("rm", "-q", "file.txt")
    h.git("commit", "-qm", "delete")
    local main, _, panel_buf = h.review()
    local row = vim.fn.search("file.txt$")
    assert(row > 0, "deleted file not listed")
    local struck = vim.iter(h.marks(panel_buf, "review_panel", row, row + 1)):any(function(mark)
        return mark[4].hl_group == "ReviewPanelDeleted"
    end)
    assert(struck, "not struck through")
    h.press("<CR>")
    local opened = vim.api.nvim_win_get_buf(main)
    assert(vim.api.nvim_buf_get_name(opened) == "review://file.txt", vim.api.nvim_buf_get_name(opened))
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(opened, 0, -1, false), h.lines(5)), "not the old contents")
    assert(not vim.bo[opened].modifiable, "modifiable")
    local marks = h.marks(opened, "review", 1, 6)
    assert(#marks == 1 and marks[1][4].end_row == 4 and marks[1][4].line_hl_group == "ReviewDelete", vim.inspect(marks))
    teardown()
end

return T
