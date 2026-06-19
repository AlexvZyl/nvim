local U = require("alex.utils")

local M = {}

local function git(file_dir, ...)
    local output = vim.fn.systemlist(vim.list_extend({ "git", "-C", file_dir }, { ... }))
    return vim.v.shell_error == 0 and output or nil
end

function M.show_line_commit()
    local file = U.current_buffer_name()
    if file == "" then
        return vim.notify("No file", vim.log.levels.WARN)
    end
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local file_dir = vim.fn.fnamemodify(file, ":h")
    local blame =
        git(file_dir, "blame", "-L", string.format("%d,%d", line, line), "--porcelain", file)
    if not blame or #blame == 0 then
        return vim.notify("Not in a git repository", vim.log.levels.WARN)
    end
    local sha = vim.split(blame[1], " ")[1]
    if not sha or sha:match("^0+$") then
        return vim.notify("Uncommitted change", vim.log.levels.INFO)
    end
    local show = git(file_dir, "show", sha)
    if not show then
        return vim.notify("Failed to show commit " .. sha, vim.log.levels.ERROR)
    end
    U.open_float(show, "git")
end

return M
