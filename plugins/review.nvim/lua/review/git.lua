local session = require("review.session")

local M = {}

function M.run(...)
    local cmd = { "git", "-C", vim.fn.getcwd(), ... }
    local result = vim.system(cmd, { text = true }):wait()
    return result.code == 0 and result.stdout or nil
end

function M.diff(...)
    return M.run("diff", "--merge-base", session.ref, ...)
end

function M.git_dir()
    return vim.trim(M.run("rev-parse", "--absolute-git-dir") or "")
end

local function head_blobs()
    local blobs = {}
    local tree = M.run("ls-tree", "-r", "-z", "--full-name", "HEAD") or ""
    for _, line in ipairs(vim.split(tree, "\0", { trimempty = true })) do
        local sha, path = line:match("^%S+ blob (%S+)\t(.+)$")
        if sha then
            blobs[path] = sha
        end
    end
    return blobs
end

function M.load()
    local numstat = M.diff("--numstat", "--relative", "-z", "--diff-filter=d", "--no-renames")
    if not numstat then
        vim.notify("git diff " .. session.ref .. " failed", vim.log.levels.ERROR)
        return false
    end
    session.prefix = vim.trim(M.run("rev-parse", "--show-prefix") or "")
    session.files = {}
    session.by_key = {}
    session.total_changes = 0
    for _, line in ipairs(vim.split(numstat, "\0", { trimempty = true })) do
        local added, deleted, path = line:match("^(%S+)\t(%S+)\t(.+)$")
        local file = {
            path = path,
            key = session.prefix .. path,
            changes = (tonumber(added) or 0) + (tonumber(deleted) or 0),
        }
        table.insert(session.files, file)
        session.by_key[file.key] = file
        session.total_changes = session.total_changes + file.changes
    end
    session.source = vim.trim(M.run("rev-parse", "--abbrev-ref", "HEAD") or "HEAD")
    session.blobs = head_blobs()
    return true
end

return M
