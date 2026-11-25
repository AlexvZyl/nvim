local M = {}

-- Starts git in the cwd. The function it returns waits for it, then gives what it parsed from the output, or nil
-- and why when git failed, like "Not a valid object name main", nil when it does not say. So functions returning it
-- run git at the same time as the others started before waiting.
local function start(args, parse)
    local process = vim.system({ "git", "-C", vim.fn.getcwd(), unpack(args) }, { text = true })
    return function()
        local result = process:wait()
        if result.code == 0 then
            return parse(result.stdout)
        end
        local reason = (result.stderr or ""):match("^fatal: ([^\n]+)") or (result.stderr or ""):match("^[^\n]+")
        return nil, reason and (reason:gsub("^%l", string.upper))
    end
end

function M.run(...)
    return start({ ... }, function(output)
        return output
    end)()
end

-- Nil when HEAD and the ref share no history.
function M.merge_base(ref)
    return start({ "merge-base", "HEAD", ref }, vim.trim)
end

-- HEAD, its branch, the path of the cwd inside the repo and the git dir. Nil outside a repo.
function M.repo()
    return start({ "rev-parse", "HEAD", "--abbrev-ref", "HEAD", "--show-prefix", "--absolute-git-dir" }, function(output)
        return unpack(vim.split(output, "\n"))
    end)
end

-- Branches, remote branches and tags.
function M.refs()
    local refs = M.run("for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes", "refs/tags") or ""
    return vim.split(refs, "\n", { trimempty = true })
end

-- Contents of a file at each revision, nil where it does not exist, read by one git process.
function M.show(file, ...)
    local revs, path = { ... }, vim.fn.fnamemodify(file, ":.")
    local objects = vim.tbl_map(function(rev)
        return rev .. ":./" .. path .. "\n"
    end, revs)
    local output = vim.system({ "git", "-C", vim.fn.getcwd(), "cat-file", "--batch" }, { stdin = table.concat(objects) }):wait().stdout or ""
    -- Each object is a header with its type and size, then its contents. Ones not found are only the header.
    local contents, position = {}, 1
    for i = 1, #revs do
        local header_end = output:find("\n", position, true)
        if not header_end then
            break
        end
        local kind, size = output:sub(position, header_end - 1):match(" (%a+) (%d+)$")
        position = header_end + 1
        if size then
            -- Without the carriage returns of CRLF files, which the buffer does not have either.
            contents[i] = kind == "blob" and (output:sub(position, position + size - 1):gsub("\r\n", "\n")) or nil
            position = position + size + 1
        end
    end
    return unpack(contents, 1, #revs)
end

-- The files of a diff --numstat -z with the lines they added and removed.
local function numstat(output)
    local files = {}
    for _, line in ipairs(vim.split(output, "\0", { trimempty = true })) do
        local added, removed, path = line:match("^(%S+)\t(%S+)\t(.+)$")
        -- Binary files count as "-", which leaves them without counts.
        table.insert(files, { path = path, added = tonumber(added), removed = tonumber(removed) })
    end
    return files
end

-- Files changed since the merge base with the ref, relative to the cwd, with the lines changed by the commits
-- alone as their changes. Nil when the diff fails.
function M.changed_files(ref)
    local args = { "diff", "--merge-base", ref, "--numstat", "--relative", "-z", "--no-renames" }
    local all, committed = start(args, numstat), start(vim.list_extend({ unpack(args, 1, 3) }, { "HEAD", unpack(args, 4) }), numstat)
    return function()
        local files, reason = all()
        if not files then
            return nil, reason
        end
        local changes = {}
        for _, file in ipairs(committed() or {}) do
            changes[file.path] = (file.added or 0) + (file.removed or 0)
        end
        for _, file in ipairs(files) do
            file.changes = changes[file.path] or 0
            -- The diff is against the working tree, so a deleted file is one not on disk.
            file.deleted = vim.uv.fs_stat(file.path) == nil
        end
        return files
    end
end

-- Blob of the files in HEAD, by path from the repo root, from their paths relative to the cwd. Waited for once
-- like the others, then kept.
function M.head_blobs(paths)
    local blobs
    -- Without paths, the whole tree.
    local wait = #paths > 0 and start({ "ls-tree", "-r", "-z", "--full-name", "HEAD", "--", unpack(paths) }, function(tree)
        return tree
    end)
    return function()
        if not blobs then
            blobs = {}
            for _, line in ipairs(vim.split(wait and wait() or "", "\0", { trimempty = true })) do
                local sha, path = line:match("^%S+ blob (%S+)\t(.+)$")
                if sha then
                    blobs[path] = sha
                end
            end
        end
        return blobs
    end
end

return M
