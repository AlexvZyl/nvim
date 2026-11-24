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

function M.head()
    return trimmed("rev-parse", "HEAD")
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

-- Branches, remote branches and tags.
function M.refs()
    local refs = M.run("for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes", "refs/tags") or ""
    return vim.split(refs, "\n", { trimempty = true })
end

-- Contents of a file at a revision, nil when it does not exist there.
function M.show(rev, file)
    return M.run("show", rev .. ":./" .. vim.fn.fnamemodify(file, ":."))
end

-- Files changed since the merge base with the ref, relative to the cwd. Nil when the diff fails.
function M.changed_files(ref)
    local numstat = M.run("diff", "--merge-base", ref, "--numstat", "--relative", "-z", "--no-renames")
    if not numstat then
        return nil
    end
    local files = {}
    for _, line in ipairs(vim.split(numstat, "\0", { trimempty = true })) do
        local added, deleted, path = line:match("^(%S+)\t(%S+)\t(.+)$")
        -- Binary files count as "-".
        table.insert(files, {
            path = path,
            changes = (tonumber(added) or 0) + (tonumber(deleted) or 0),
            -- The diff is against the working tree, so a deleted file is one not on disk.
            deleted = vim.uv.fs_stat(path) == nil,
        })
    end
    return files
end

-- Blob of the files in HEAD, by path from the repo root, from their paths relative to the cwd.
function M.head_blobs(paths)
    local blobs = {}
    -- Without paths, the whole tree.
    local tree = #paths > 0 and M.run("ls-tree", "-r", "-z", "--full-name", "HEAD", "--", unpack(paths)) or ""
    for _, line in ipairs(vim.split(tree, "\0", { trimempty = true })) do
        local sha, path = line:match("^%S+ blob (%S+)\t(.+)$")
        if sha then
            blobs[path] = sha
        end
    end
    return blobs
end

return M
