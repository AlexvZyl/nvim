local h = require("tests.helpers")

local T = {}

-- Committed: line 10 modified. Uncommitted: line 5 modified, line 7 deleted and the committed line 10 deleted.
local function setup()
    local base = h.lines(12)
    local committed = vim.deepcopy(base)
    committed[10] = "mod 10"
    local working = vim.deepcopy(committed)
    working[5] = "local 5"
    table.remove(working, 10)
    table.remove(working, 7)
    h.repo(base, committed, working)
    return h.open()
end

local function find(marks, line)
    for _, mark in ipairs(marks) do
        if mark[2] + 1 == line then
            return mark
        end
    end
end

function T.committed_lines_have_a_solid_sign_and_background()
    local base = h.lines(12)
    local committed = vim.deepcopy(base)
    committed[10] = "mod 10"
    h.repo(base, committed)
    local buf = h.open()
    local mark = find(h.marks(buf, "review", 1, 12), 10)
    assert(mark, "no mark on the committed line")
    assert(mark[4].sign_text == "│ ", vim.inspect(mark[4].sign_text))
    assert(mark[4].line_hl_group == "ReviewAdd")
    local deleted = h.virt_lines(find(h.marks(buf, "review_deleted", 1, 12), 10))
    assert(#deleted == 1 and deleted[1].text == "line 10" and deleted[1].sign == "│", vim.inspect(deleted))
    assert(deleted[1].group == "ReviewSignDelete")
end

function T.uncommitted_lines_have_a_dashed_sign()
    local buf = setup()
    local mark = find(h.marks(buf, "review", 1, 12), 5)
    assert(mark, "no mark on the uncommitted line")
    assert(mark[4].sign_text == "╎ ", vim.inspect(mark[4].sign_text))
    assert(mark[4].sign_hl_group == "ReviewSignLocalAdd")
    assert(mark[4].line_hl_group == "ReviewLocalAdd")
end

function T.uncommitted_deletions_are_shown_with_a_dashed_sign()
    local buf = setup()
    local deleted = {}
    for _, mark in ipairs(h.marks(buf, "review_deleted", 1, 12)) do
        vim.list_extend(deleted, h.virt_lines(mark))
    end
    local by_text = {}
    for _, line in ipairs(deleted) do
        by_text[line.text] = line
    end
    assert(by_text["line 5"] and by_text["line 5"].group == "ReviewSignLocalDelete", vim.inspect(deleted))
    assert(by_text["line 7"] and by_text["line 7"].sign == "╎", vim.inspect(deleted))
    -- Deleting a line added by a commit shows it as deleted locally, under the line it replaced.
    assert(by_text["mod 10"] and by_text["mod 10"].group == "ReviewSignLocalDelete", vim.inspect(deleted))
    assert(by_text["line 10"] and by_text["line 10"].group == "ReviewSignDelete", vim.inspect(deleted))
end

-- The text of all deleted lines from the top, in the order they show.
local function deleted_texts(buf)
    local texts = {}
    for _, mark in ipairs(h.marks(buf, "review_deleted", 1, vim.api.nvim_buf_line_count(buf))) do
        for _, line in ipairs(h.virt_lines(mark)) do
            table.insert(texts, line.text)
        end
    end
    return texts
end

function T.deleted_lines_show_in_order_when_deleted_before_committed_deletions()
    local base = h.lines(12)
    local committed = vim.deepcopy(base)
    table.remove(committed, 7)
    table.remove(committed, 6)
    local working = vim.deepcopy(committed)
    table.remove(working, 5)
    h.repo(base, committed, working)
    local texts = deleted_texts(h.open())
    assert(vim.deep_equal(texts, { "line 5", "line 6", "line 7" }), vim.inspect(texts))
end

function T.deleted_lines_show_in_order_when_deleted_after_committed_deletions()
    local base = h.lines(12)
    local committed = vim.deepcopy(base)
    table.remove(committed, 6)
    local working = vim.deepcopy(committed)
    table.remove(working, 6)
    h.repo(base, committed, working)
    local texts = deleted_texts(h.open())
    assert(vim.deep_equal(texts, { "line 6", "line 7" }), vim.inspect(texts))
end

function T.deleted_lines_show_in_order_when_a_committed_change_is_deleted()
    local base = h.lines(12)
    local committed = vim.deepcopy(base)
    committed[6] = "mod 6"
    local working = vim.deepcopy(committed)
    table.remove(working, 6)
    h.repo(base, committed, working)
    local texts = deleted_texts(h.open())
    assert(vim.deep_equal(texts, { "line 6", "mod 6" }), vim.inspect(texts))
end

function T.deleting_everything_renders()
    local base = h.lines(3)
    h.repo(base, base, {})
    local buf = h.open()
    local marks = h.marks(buf, "review_deleted", 1, 1)
    assert(#marks == 1 and #h.virt_lines(marks[1]) == 3, vim.inspect(marks))
end

function T.deletion_at_the_end_goes_below_the_last_line()
    local base = h.lines(5)
    local committed = vim.list_slice(base, 1, 4)
    h.repo(base, committed)
    local buf = h.open()
    local mark = h.marks(buf, "review_deleted", 1, 5)[1]
    assert(mark and mark[2] == 3 and not mark[4].virt_lines_above, vim.inspect(mark))
end

function T.edits_rerender()
    local base = h.lines(12)
    h.repo(base, base)
    local buf = h.open()
    assert(#h.marks(buf, "review", 1, 12) == 0)
    vim.cmd("normal! 3G")
    h.keys("Ax")
    local mark = find(h.marks(buf, "review", 1, 12), 3)
    assert(mark and mark[4].sign_hl_group == "ReviewSignLocalAdd", vim.inspect(mark))
end

-- TextChanged comes before the redraw, rendered later the edit flashes without the deleted lines.
function T.deleted_lines_render_before_the_redraw()
    local base = h.lines(12)
    h.repo(base, base)
    local buf = h.open()
    vim.cmd("normal! 5Gdd")
    require("review.render").update(buf)
    local deleted = h.virt_lines(h.marks(buf, "review_deleted", 1, 12)[1] or { 0, 0, 0, {} })
    assert(#deleted == 1 and deleted[1].text == "line 5", vim.inspect(deleted))
end

function T.lines_deleted_at_the_top_show_when_opened()
    local base = h.lines(12)
    h.repo(base, vim.list_slice(base, 3))
    vim.cmd("silent! only | enew | silent! %bwipeout!")
    local main = vim.api.nvim_get_current_win()
    h.start()
    vim.api.nvim_set_current_win(main)
    vim.cmd.edit("file.txt")
    local topfill = vim.fn.winsaveview().topfill
    require("review").stop()
    assert(topfill == 2, topfill)
end

-- The panel puts the first hunk in the middle of the window, which hides what is above the first line again.
function T.lines_deleted_at_the_top_show_when_opened_from_the_panel()
    local base = h.lines(12)
    h.repo(base, vim.list_slice(base, 3))
    vim.cmd("silent! only | enew | silent! %bwipeout!")
    local main = vim.api.nvim_get_current_win()
    h.start()
    vim.fn.cursor(vim.fn.search("file.txt$"), 1)
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    local topfill = vim.api.nvim_win_call(main, vim.fn.winsaveview).topfill
    require("review").stop()
    assert(topfill == 2, topfill)
end

-- A statuscolumn with relative numbers measures narrower right after an edit, until the redraw.
function T.deleted_lines_keep_the_gutter_width_while_editing()
    local base = h.lines(20)
    h.repo(base, base)
    local buf = h.open()
    vim.wo.number, vim.wo.relativenumber = true, true
    vim.wo.statuscolumn = "%#LineNr# %*%s%=%{v:relnum?v:relnum:v:lnum}%*  "
    vim.cmd("redraw")
    h.keys("5Gdd")
    h.keys("u")
    local width = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
    vim.cmd("normal! 5Gdd")
    require("review.render").update(buf)
    local mark = h.marks(buf, "review_deleted", 1, 20)[1]
    vim.wo.number, vim.wo.relativenumber, vim.wo.statuscolumn = false, false, ""
    local chunks = mark[4].virt_lines[1]
    local gutter = vim.fn.strdisplaywidth(chunks[1][1] .. chunks[2][1])
    assert(gutter == width, ("gutter %d, window %d"):format(gutter, width))
end

function T.untracked_and_binary_files_are_not_rendered()
    h.repo(h.lines(3), h.lines(4))
    local function binary(text)
        local file = assert(io.open("binary.bin", "wb"))
        file:write(text)
        file:close()
    end
    binary("a\0b")
    vim.system({ "git", "add", "binary.bin" }):wait()
    vim.system({ "git", "commit", "-qm", "binary" }):wait()
    binary("c\0d")
    vim.fn.writefile({ "new" }, "untracked.txt")
    h.open()
    for _, name in ipairs({ "binary.bin", "untracked.txt" }) do
        vim.cmd.edit(name)
        local buf = vim.api.nvim_get_current_buf()
        require("review.render").attach(buf)
        assert(not require("review.render").first_hunk(buf), name .. " attached")
        assert(#h.marks(buf, "review", 1, 2) == 0, name .. " has marks")
    end
end

function T.hunk_jumps_stop_at_the_first_and_last_hunk()
    local base = h.lines(30)
    local committed = vim.deepcopy(base)
    for _, line in ipairs({ 5, 15, 25 }) do
        committed[line] = "mod " .. line
    end
    h.repo(base, committed)
    h.open()
    local function jump(keys)
        vim.cmd("normal " .. keys)
        return vim.fn.line(".")
    end
    vim.cmd("normal! 1G")
    local lines = { jump("]h"), jump("]h"), jump("]h"), jump("]h"), jump("[h"), jump("[h"), jump("[h") }
    assert(vim.deep_equal(lines, { 5, 15, 25, 25, 15, 5, 5 }), vim.inspect(lines))
end

function T.an_invalid_ref_keeps_the_review()
    h.repo(h.lines(3), h.lines(4))
    vim.cmd("silent! only | enew | silent! %bwipeout!")
    h.start()
    local notify = vim.notify
    vim.notify = function() end
    require("review").start("nope")
    vim.notify = notify
    local session = require("review.session")
    local ref, open = session.ref, require("review.panel").is_open()
    require("review").stop()
    assert(ref == "dev" and open, vim.inspect({ ref, open }))
end

return T
