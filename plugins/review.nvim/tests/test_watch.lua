local h = require("tests.helpers")

local T = {}

local function git(...)
    local result = vim.system({ "git", ... }, { text = true }):wait()
    assert(result.code == 0, table.concat({ ... }, " ") .. ": " .. (result.stderr or ""))
end

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

-- The review running with file.txt open in the window next to the panel.
local function start()
    vim.o.lines = 40
    vim.o.columns = 200
    vim.cmd("silent! only | enew | silent! %bwipeout!")
    local main = vim.api.nvim_get_current_win()
    h.start()
    vim.api.nvim_set_current_win(main)
    return main
end

local function sign(buf, line)
    local mark = h.marks(buf, "review", line, line + 1)[1]
    return mark and mark[4].sign_text
end

function T.switching_branch_reloads_the_files()
    h.repo(h.lines(5), h.lines(6))
    git("checkout", "-qb", "other", "dev")
    vim.fn.writefile({ "a" }, "other.txt")
    git("add", ".")
    git("commit", "-qm", "other")
    git("checkout", "-q", "branch")
    start()
    assert(panel_lines():match("file.txt") and not panel_lines():match("other.txt"), panel_lines())
    local notified
    local notify = vim.notify
    vim.notify = function(message)
        notified = message
    end
    git("checkout", "-q", "other")
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
    local base = h.lines(10)
    local committed = vim.deepcopy(base)
    committed[3] = "branch 3"
    h.repo(base, committed)
    git("checkout", "-q", "dev")
    local moved = vim.deepcopy(base)
    moved[3] = "branch 3"
    vim.fn.writefile(moved, "file.txt")
    git("commit", "-qam", "dev")
    git("checkout", "-qb", "other")
    git("checkout", "-q", "branch")
    start()
    vim.cmd.edit("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    assert(sign(buf, 3), "line 3 not changed")
    git("checkout", "-q", "other")
    vim.cmd("checktime")
    wait(function()
        return sign(buf, 3) == nil
    end, "line 3 still changed")
    require("review").stop()
end

-- Same merge base, but what is committed moved.
function T.committing_restyles_local_changes()
    local base = h.lines(10)
    local working = vim.deepcopy(base)
    working[3] = "local 3"
    h.repo(base, base, working)
    start()
    vim.cmd.edit("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    assert(sign(buf, 3) == "╎ ", vim.inspect(sign(buf, 3)))
    git("commit", "-qam", "commit")
    wait(function()
        return sign(buf, 3) == "│ "
    end, "still local: " .. vim.inspect(sign(buf, 3)))
    require("review").stop()
end

function T.a_deleted_file_restored_by_switching_branch_goes()
    h.repo(h.lines(5), h.lines(5))
    git("checkout", "-qb", "other", "dev")
    vim.fn.writefile({ "a" }, "other.txt")
    git("add", ".")
    git("commit", "-qm", "other")
    git("checkout", "-q", "branch")
    git("rm", "-q", "file.txt")
    git("commit", "-qm", "delete")
    local main = start()
    vim.api.nvim_win_set_buf(main, require("review.render").deleted_buffer("file.txt"))
    git("checkout", "-q", "other")
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
    local main = start()
    local buf = require("review.render").deleted_buffer("file.txt")
    vim.api.nvim_win_set_buf(main, buf)
    assert(sign(buf, 1) == "╎ ", vim.inspect(sign(buf, 1)))
    git("commit", "-qam", "delete")
    wait(function()
        return sign(buf, 1) == "│ "
    end, "still local: " .. vim.inspect(sign(buf, 1)))
    require("review").stop()
end

return T
