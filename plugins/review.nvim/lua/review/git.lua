local M = {}

-- Starts git and returns a function that waits for it, giving the parsed output, or nil and git's reason.
local function spawn(args, parse)
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
    return spawn({ ... }, function(output)
        return output
    end)()
end

-- Nil when HEAD and the ref share no history.
function M.merge_base(ref)
    return spawn({ "merge-base", "HEAD", ref }, vim.trim)
end

-- HEAD, its branch, the cwd's repo path and the git dir. Nil outside a repo.
function M.repo_info()
    return spawn({ "rev-parse", "HEAD", "--abbrev-ref", "HEAD", "--show-prefix", "--absolute-git-dir" }, function(output)
        return unpack(vim.split(output, "\n"))
    end)
end

-- Branches, remote branches and tags.
function M.refs()
    local refs = M.run("for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes", "refs/tags") or ""
    return vim.split(refs, "\n", { trimempty = true })
end

-- Contents by path, then revision, nil where missing, from one git process. A revision can be a function of the
-- cwd path returning an object, like a blob hash.
function M.show_each(paths, revisions)
    local objects, object_index = {}, {}
    for i, path in ipairs(paths) do
        local cwd_path = vim.fn.fnamemodify(path, ":.")
        object_index[i] = {}
        for j, revision in ipairs(revisions) do
            local object = type(revision) == "function" and revision(cwd_path)
                or type(revision) == "string" and revision .. ":./" .. cwd_path
            if object then
                table.insert(objects, object .. "\n")
                object_index[i][j] = #objects
            end
        end
    end
    local output = vim.system({ "git", "-C", vim.fn.getcwd(), "cat-file", "--batch" }, { stdin = table.concat(objects) }):wait().stdout or ""
    -- A header with type and size, then the contents. Missing objects have only the header.
    local contents, position = {}, 1
    for i = 1, #objects do
        local header_end = output:find("\n", position, true)
        if not header_end then
            break
        end
        local object_type, size = output:sub(position, header_end - 1):match(" (%a+) (%d+)$")
        position = header_end + 1
        if size then
            -- Without carriage returns, like the buffer.
            contents[i] = object_type == "blob" and (output:sub(position, position + size - 1):gsub("\r\n", "\n")) or nil
            position = position + size + 1
        end
    end
    local by_path = {}
    for i = 1, #paths do
        by_path[i] = {}
        for j, index in pairs(object_index[i]) do
            by_path[i][j] = contents[index]
        end
    end
    return by_path
end

function M.show(path, ...)
    return unpack(M.show_each({ path }, { ... })[1], 1, select("#", ...))
end

local function numstat(output)
    local files = {}
    for added, removed, path in output:gmatch("(%S+)\t(%S+)\t([^%z]+)%z") do
        -- Binary files count as "-".
        table.insert(files, { path = path, lines_added = tonumber(added), lines_removed = tonumber(removed) })
    end
    return files
end

-- Changed since the merge base, committed or not, under the cwd.
function M.changed_files(ref)
    return spawn({ "diff", "--merge-base", ref, "--numstat", "--relative", "-z", "--no-renames" }, numstat)
end

-- Waits for the HEAD blob hash of each file, by repo path, then caches them.
function M.head_hashes(paths)
    local hashes
    -- Without paths, the whole tree.
    local wait_for_tree = #paths > 0
        and spawn({ "ls-tree", "-r", "-z", "--full-name", "HEAD", "--", unpack(paths) }, function(tree)
            return tree
        end)
    return function()
        if not hashes then
            hashes = {}
            for hash, repo_path in (wait_for_tree and wait_for_tree() or ""):gmatch("%S+ blob (%S+)\t([^%z]+)%z") do
                hashes[repo_path] = hash
            end
        end
        return hashes
    end
end

-- Watching HEAD

local timer, watcher, on_change

-- Debounced, as a rebase moves HEAD for every commit.
function M.schedule_change()
    if timer then
        timer:stop()
        timer:start(200, 0, vim.schedule_wrap(on_change))
    end
end

-- Calls back when HEAD moves, which git appends to the HEAD reflog for.
function M.watch(git_dir, callback)
    on_change = callback
    timer = vim.uv.new_timer()
    watcher = vim.uv.new_fs_event()
    local reflog_path = git_dir .. "/logs/HEAD"
    local function start()
        watcher:start(reflog_path, {}, function(watch_error)
            if watch_error then
                return
            end
            -- Git may have replaced the file.
            watcher:stop()
            start()
            M.schedule_change()
        end)
    end
    start()
end

function M.unwatch()
    for _, handle in ipairs({ timer, watcher }) do
        if not handle:is_closing() then
            handle:close()
        end
    end
    timer, watcher = nil, nil
end

return M
