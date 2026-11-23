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

return T
