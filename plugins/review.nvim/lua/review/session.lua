local git = require("review.git")

-- What is being reviewed. Only this module writes it.
local M = {}

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
    -- Required here, as review.file requires this module.
    local File = require("review.file")
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

-- False when the diff failed.
function M.load()
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
