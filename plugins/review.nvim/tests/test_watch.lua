local h = require("tests.helpers")

local T = {}

-- Until the watcher has reloaded after git moved HEAD.
local function wait(condition, message)
    assert(vim.wait(3000, condition, 20), message)
end

local function panel_lines()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "review" then
            return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        end
    end
    return ""
end

local function sign(buf, line)
    local mark = h.marks(buf, "review", line, line)[1]
    return mark and mark[4].sign_text
end

function T.switching_branch_reloads_the_files()
    h.repo(h.lines(5), h.lines(6))
    h.git("checkout", "-qb", "other", "dev")
    vim.fn.writefile({ "a" }, "other.txt")
    h.git("add", ".")
    h.git("commit", "-qm", "other")
    h.git("checkout", "-q", "branch")
    h.review()
    assert(panel_lines():match("file.txt") and not panel_lines():match("other.txt"), panel_lines())
    local notified
    local notify = vim.notify
    vim.notify = function(message)
        notified = message
    end
    h.git("checkout", "-q", "other")
    wait(function()
        return panel_lines():match("other.txt") ~= nil
    end, "panel not reloaded")
    vim.notify = notify
    assert(not panel_lines():match("file.txt"), panel_lines())
    assert(notified == "Reviewing other against dev", tostring(notified))
    require("review").stop()
end

-- dev moved on after the branch, and the other branch starts from there.
function T.switching_to_a_new_merge_base_rerenders()
    local committed = h.edit(h.lines(10), { [3] = "branch 3" })
    h.repo(h.lines(10), committed)
    h.git("checkout", "-q", "dev")
    vim.fn.writefile(committed, "file.txt")
    h.git("commit", "-qam", "dev")
    h.git("checkout", "-qb", "other")
    h.git("checkout", "-q", "branch")
    h.review("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    assert(sign(buf, 3), "line 3 not changed")
    h.git("checkout", "-q", "other")
    vim.cmd("checktime")
    wait(function()
        return sign(buf, 3) == nil
    end, "line 3 still changed")
    require("review").stop()
end

-- Same merge base, but what is committed moved.
function T.committing_restyles_local_changes()
    h.repo(h.lines(10), h.lines(10), h.edit(h.lines(10), { [3] = "local 3" }))
    h.review("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    assert(sign(buf, 3) == "╎ ", vim.inspect(sign(buf, 3)))
    h.git("commit", "-qam", "commit")
    wait(function()
        return sign(buf, 3) == "│ "
    end, "still local: " .. vim.inspect(sign(buf, 3)))
    require("review").stop()
end

function T.a_deleted_file_restored_by_switching_branch_goes()
    h.repo(h.lines(5), h.lines(5))
    h.git("checkout", "-qb", "other", "dev")
    vim.fn.writefile({ "a" }, "other.txt")
    h.git("add", ".")
    h.git("commit", "-qm", "other")
    h.git("checkout", "-q", "branch")
    h.git("rm", "-q", "file.txt")
    h.git("commit", "-qm", "delete")
    local main = h.review()
    vim.api.nvim_win_set_buf(main, require("review.deleted").open("file.txt"))
    h.git("checkout", "-q", "other")
    wait(function()
        return vim.fn.bufnr("review://file.txt") == -1
    end, "deleted file buffer left")
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(main))
    assert(vim.fn.fnamemodify(name, ":t") == "file.txt", name)
    require("review").stop()
end

function T.committing_a_deletion_restyles_its_buffer()
    h.repo(h.lines(5), h.lines(5))
    os.remove("file.txt")
    local main = h.review()
    local buf = require("review.deleted").open("file.txt")
    vim.api.nvim_win_set_buf(main, buf)
    assert(sign(buf, 1) == "╎ ", vim.inspect(sign(buf, 1)))
    h.git("commit", "-qam", "delete")
    wait(function()
        return sign(buf, 1) == "│ "
    end, "still local: " .. vim.inspect(sign(buf, 1)))
    require("review").stop()
end

-- Reviewed at the blob in HEAD, so only a commit changing it again brings it back.
function T.a_reviewed_file_comes_back_changed_once_committed_again()
    h.repo(h.lines(5), h.lines(6))
    local _, _, panel_buf = h.review()
    vim.fn.cursor(vim.fn.search("file.txt$"), 1)
    vim.api.nvim_feedkeys("dd", "x", false)
    assert(not panel_lines():match("file.txt"), panel_lines())
    vim.fn.writefile(h.lines(7), "file.txt")
    h.git("commit", "-qam", "again")
    wait(function()
        return panel_lines():match("file.txt") ~= nil
    end, "reviewed file not back")
    local mark = h.marks(panel_buf, "review_panel", 1, 1)[1]
    require("review").stop()
    assert(mark and mark[4].virt_text and mark[4].virt_text[1][2] == "ReviewChanged", vim.inspect(mark))
end

-- A file that comes in once the review was saved is marked new until opened.
function T.a_file_added_later_is_new_until_opened()
    h.repo(h.lines(5), h.lines(6))
    local main, panel, panel_buf = h.review()
    local function dot()
        local row = vim.fn.search("added.txt$") - 1
        local mark = h.marks(panel_buf, "review_panel", row + 1, row + 1)[1]
        return mark and mark[4].virt_text and mark[4].virt_text[1][2]
    end
    -- Saves the state with the file seen.
    vim.api.nvim_feedkeys("ddu", "x", false)
    vim.fn.writefile({ "a" }, "added.txt")
    h.git("add", ".")
    h.git("commit", "-qm", "added")
    wait(function()
        return panel_lines():match("added.txt") ~= nil
    end, "added file not listed")
    local marked = dot()
    vim.api.nvim_set_current_win(panel)
    vim.fn.cursor(vim.fn.search("added.txt$"), 1)
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    local opened = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(main))
    local cleared = dot()
    require("review").stop()
    assert(marked == "ReviewNew" and not cleared and opened:match("added.txt$"), vim.inspect({ marked, cleared, opened }))
end

return T
