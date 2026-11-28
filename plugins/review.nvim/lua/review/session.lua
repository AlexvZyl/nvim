-- The review: what is being reviewed, its files and the saved progress. Only this module writes it.
local config = require("review.config")
local git = require("review.git")

local M = {}

-- Progress

-- The saved JSON, by repo path: reviewed blob hashes, seen files, and undo/redo snapshots.
local saved = { reviewed = {}, seen = {}, undo = {}, redo = {} }

local function progress_file()
    local name = (M.branch .. ".." .. M.base_ref):gsub("/", "%%")
    return M.git_dir .. "/review/" .. name .. ".json"
end

-- Tolerates broken or old saved progress.
function M.load_progress()
    local ok, decoded = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(progress_file()), "\n"))
    end)
    decoded = ok and type(decoded) == "table" and decoded or {}
    local function valid_snapshots(stack)
        return vim.tbl_filter(function(snapshot)
            return type(snapshot) == "table" and type(snapshot.changes) == "table"
        end, type(stack) == "table" and stack or {})
    end
    -- Without saved progress nothing is unseen.
    local seen = type(decoded.seen) == "table" and decoded.seen
        or vim.tbl_map(function(file)
            return file.repo_path
        end, M.files)
    local reviewed = type(decoded.reviewed) == "table" and decoded.reviewed or {}
    saved = { reviewed = reviewed, seen = {}, undo = valid_snapshots(decoded.undo), redo = valid_snapshots(decoded.redo) }
    for _, repo_path in ipairs(seen) do
        saved.seen[repo_path] = true
    end
end

local function save_progress()
    local path = progress_file()
    -- An empty table encodes as a list, which loads the same.
    local encoded = vim.json.encode({ reviewed = saved.reviewed, seen = vim.tbl_keys(saved.seen), undo = saved.undo, redo = saved.redo })
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({ encoded }, path .. ".tmp")
    vim.uv.fs_rename(path .. ".tmp", path)
end

function M.reset_progress()
    os.remove(progress_file())
    M.load_progress()
end

-- Empty when not in HEAD.
local function head_hash(repo_path)
    return M.head_hashes()[repo_path] or ""
end

function M.needs_review(repo_path)
    return saved.reviewed[repo_path] ~= head_hash(repo_path)
end

function M.changed_after_review(repo_path)
    local reviewed_hash = saved.reviewed[repo_path]
    return reviewed_hash ~= nil and reviewed_hash ~= head_hash(repo_path)
end

-- Nil when not reviewed.
function M.reviewed_hash(repo_path)
    return saved.reviewed[repo_path]
end

function M.is_unseen(repo_path)
    return not saved.seen[repo_path]
end

local function snapshot(repo_paths, cursor_line)
    local changes = {}
    for _, repo_path in ipairs(repo_paths) do
        changes[repo_path] = { reviewed = saved.reviewed[repo_path] or false, seen = saved.seen[repo_path] or false }
    end
    return { changes = changes, cursor = cursor_line }
end

function M.review(repo_paths, cursor_line)
    table.insert(saved.undo, snapshot(repo_paths, cursor_line))
    saved.redo = {}
    for _, repo_path in ipairs(repo_paths) do
        saved.reviewed[repo_path] = head_hash(repo_path)
        saved.seen[repo_path] = true
    end
    save_progress()
end

-- Clears a file's dot: unreviewed and seen.
function M.mark_opened(repo_path)
    saved.reviewed[repo_path] = nil
    saved.seen[repo_path] = true
    save_progress()
end

-- Pops a snapshot from one stack, pushing the current state to the other.
local function restore(from_stack, to_stack, cursor_line)
    if #saved[from_stack] == 0 then
        return nil
    end
    -- Skips snapshots that change nothing.
    local snapshot_restored, any_changed
    repeat
        snapshot_restored = table.remove(saved[from_stack])
        table.insert(saved[to_stack], snapshot(vim.tbl_keys(snapshot_restored.changes), cursor_line))
        for repo_path, before in pairs(snapshot_restored.changes) do
            any_changed = any_changed
                or (saved.reviewed[repo_path] or false) ~= before.reviewed
                or (saved.seen[repo_path] or false) ~= before.seen
            saved.reviewed[repo_path] = before.reviewed or nil
            saved.seen[repo_path] = before.seen or nil
        end
    until any_changed or #saved[from_stack] == 0
    save_progress()
    return snapshot_restored.cursor, vim.tbl_keys(snapshot_restored.changes)
end

function M.undo(cursor_line)
    return restore("undo", "redo", cursor_line)
end

function M.redo(cursor_line)
    return restore("redo", "undo", cursor_line)
end

-- File

-- File is one changed file in the review, with its line counts and review status.
local File = {}
File.__index = File

-- Counts are nil for binary files.
function File.new(path, lines_added, lines_removed)
    return setmetatable({
        -- From the cwd.
        path = path,
        -- From the repo root. Progress is saved by it, so it does not depend on the cwd.
        repo_path = M.cwd_prefix .. path,
        lines_added_since_merge_base = lines_added,
        lines_removed_since_merge_base = lines_removed,
        -- Its share of the progress %: changed lines, at least 1.
        progress_weight = math.max((lines_added or 0) + (lines_removed or 0), 1),
        is_deleted = (lines_added or 0) == 0 and vim.uv.fs_stat(path) == nil,
        -- { hash, lines_added, lines_removed }, set by count_lines_since_review.
        since_review = nil,
    }, File)
end

function File:needs_review()
    return M.needs_review(self.repo_path)
end

function File:changed_after_review()
    return M.changed_after_review(self.repo_path)
end

function File:is_unseen()
    return M.is_unseen(self.repo_path)
end

-- Nil when not reviewed.
function File:reviewed_hash()
    return M.reviewed_hash(self.repo_path)
end

-- Since review in the since_review view when counted, else since the merge base.
function File:counts_to_show()
    local since_review = config.options.view == "since_review" and self.since_review
    if since_review and since_review.lines_added and since_review.hash == self:reviewed_hash() then
        return since_review.lines_added, since_review.lines_removed
    end
    return self.lines_added_since_merge_base, self.lines_removed_since_merge_base
end

-- Sets since_review on files changed after review, reading every reviewed version with one git process.
function M.count_lines_since_review(files)
    local to_count = {}
    for _, file in ipairs(files) do
        local reviewed_hash = file:changed_after_review() and file:reviewed_hash()
        local counted_already = file.since_review and file.since_review.hash == reviewed_hash
        if reviewed_hash and file.lines_added_since_merge_base and not counted_already then
            table.insert(to_count, file)
        end
    end
    if #to_count == 0 then
        return
    end
    local paths, reviewed_hash_by_path = {}, {}
    for i, file in ipairs(to_count) do
        paths[i], reviewed_hash_by_path[file.path] = file.path, file:reviewed_hash()
    end
    local contents = git.show_each(paths, {
        function(path)
            return reviewed_hash_by_path[path]
        end,
    })
    for i, file in ipairs(to_count) do
        file.since_review = { hash = file:reviewed_hash() }
        local reviewed_content = contents[i][1]
        if reviewed_content then
            -- Against the file on disk like git's counts, without carriage returns like the blob.
            local handle = io.open(file.path, "rb")
            local current_content = handle and handle:read("*a"):gsub("\r\n", "\n") or ""
            if handle then
                handle:close()
            end
            local lines_added, lines_removed = 0, 0
            for _, hunk in ipairs(vim.text.diff(reviewed_content, current_content, { result_type = "indices" })) do
                local _, old_count, _, new_count = unpack(hunk)
                lines_removed, lines_added = lines_removed + old_count, lines_added + new_count
            end
            file.since_review.lines_added, file.since_review.lines_removed = lines_added, lines_removed
        end
    end
end

-- Session

local function clear()
    -- Nil when no review is running.
    M.base_ref = nil
    M.branch = nil
    M.merge_base = nil
    -- As of the last load.
    M.head_commit = nil
    M.git_dir = nil
    -- The cwd's path from the repo root.
    M.cwd_prefix = ""
    M.files = {}
    M.by_repo_path = {}
    M.total_progress_weight = 0
    -- Waits for the HEAD blob hash of each file, by repo path.
    M.head_hashes = function()
        return {}
    end
end

clear()

local function set_files(entries)
    M.files, M.by_repo_path, M.total_progress_weight = {}, {}, 0
    for i, entry in ipairs(entries) do
        local file = File.new(entry.path, entry.lines_added, entry.lines_removed)
        M.files[i], M.by_repo_path[file.repo_path] = file, file
        M.total_progress_weight = M.total_progress_weight + file.progress_weight
    end
    -- Waited for when needed.
    M.head_hashes = git.head_hashes(vim.tbl_map(function(entry)
        return entry.path
    end, entries))
end

-- Not an error, which vim.cmd would raise.
local function warn(message, reason)
    vim.notify(message .. (reason and ": " .. reason or ""), vim.log.levels.WARN)
end

-- False when there is no merge base or the diff failed.
function M.start(base_ref)
    -- All at once, as the diff takes the longest.
    local wait_for_files, wait_for_merge_base, wait_for_repo = git.changed_files(base_ref), git.merge_base(base_ref), git.repo_info()
    local merge_base, merge_base_error = wait_for_merge_base()
    local entries, diff_error = wait_for_files()
    if not merge_base then
        -- Git gives no reason for unrelated histories.
        warn(merge_base_error and "Cannot review against " .. base_ref or "HEAD shares no history with " .. base_ref, merge_base_error)
        return false
    elseif not entries then
        warn("git diff " .. base_ref .. " failed", diff_error)
        return false
    end
    clear()
    M.base_ref, M.merge_base = base_ref, merge_base
    M.head_commit, M.branch, M.cwd_prefix, M.git_dir = wait_for_repo()
    set_files(entries)
    return true
end

M.stop = clear

function M.active()
    return M.base_ref ~= nil
end

-- Reloads the files from git. False when the diff failed.
function M.reload()
    -- All at once, as the diff takes the longest.
    local wait_for_files, wait_for_merge_base, wait_for_repo = git.changed_files(M.base_ref), git.merge_base(M.base_ref), git.repo_info()
    local entries, diff_error = wait_for_files()
    if not entries then
        warn("git diff " .. M.base_ref .. " failed", diff_error)
        return false
    end
    M.merge_base = wait_for_merge_base()
    M.head_commit, M.branch, M.cwd_prefix = wait_for_repo()
    set_files(entries)
    return true
end

return M
