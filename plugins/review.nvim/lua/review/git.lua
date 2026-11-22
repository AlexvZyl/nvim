local M = {}

function M.run(...)
    local cmd = { "git", "-C", vim.fn.getcwd(), ... }
    local result = vim.system(cmd, { text = true }):wait()
    return result.code == 0 and result.stdout or nil
end

local function trimmed(...)
    local output = M.run(...)
    return output and vim.trim(output)
end

-- Nil when HEAD and the ref share no history.
function M.merge_base(ref)
    return trimmed("merge-base", "HEAD", ref)
end

function M.branch()
    return trimmed("rev-parse", "--abbrev-ref", "HEAD") or "HEAD"
end

-- Path of the cwd inside the repo.
function M.prefix()
    return trimmed("rev-parse", "--show-prefix") or ""
end

function M.git_dir()
    return trimmed("rev-parse", "--absolute-git-dir") or ""
end

-- Contents of a file at a revision, nil when it does not exist there.
function M.show(rev, file)
    return M.run("show", rev .. ":./" .. vim.fn.fnamemodify(file, ":."))
end

-- Files changed since the merge base with the ref, relative to the cwd. Nil when the diff fails.
function M.changed_files(ref)
    local numstat = M.run("diff", "--merge-base", ref, "--numstat", "--relative", "-z", "--diff-filter=d", "--no-renames")
    if not numstat then
        return nil
    end
    local files = {}
    for _, line in ipairs(vim.split(numstat, "\0", { trimempty = true })) do
        local added, deleted, path = line:match("^(%S+)\t(%S+)\t(.+)$")
        -- Binary files count as "-".
        table.insert(files, { path = path, changes = (tonumber(added) or 0) + (tonumber(deleted) or 0) })
    end
    return files
end

-- Blob of every file in HEAD, by path from the repo root.
function M.head_blobs()
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

return M
