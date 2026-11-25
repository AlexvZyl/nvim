local git = require("review.git")

-- What is being reviewed. Only this module writes it, the others read it.
local M = {}

local function clear()
    -- Ref being reviewed against, nil when no review is running.
    M.ref = nil
    -- Branch being reviewed.
    M.source = nil
    M.merge_base = nil
    -- Commit HEAD was on when the files were last loaded.
    M.head = nil
    M.git_dir = nil
    M.prefix = ""
    -- Changed files with their path from the cwd, key from the repo root and number of changed lines.
    M.files = {}
    M.by_key = {}
    M.total_changes = 0
    -- Waits for the blob of the files in HEAD, by key.
    M.blobs = function()
        return {}
    end
end

clear()

local function set_files(files)
    M.files, M.by_key, M.total_changes = files, {}, 0
    for _, file in ipairs(files) do
        file.key = M.prefix .. file.path
        M.by_key[file.key] = file
        M.total_changes = M.total_changes + file.changes
    end
    -- Waited for once needed, so git reads them meanwhile.
    M.blobs = git.head_blobs(vim.tbl_map(function(file)
        return file.path
    end, files))
end

-- A warning and not an error, which Neovim raises as one when the command runs from vim.cmd, like lazy.nvim does
-- for the first one.
local function warn(message, reason)
    vim.notify(message .. (reason and ": " .. reason or ""), vim.log.levels.WARN)
end

-- Starts with the changed files loaded, false when HEAD has no merge base with the ref or the diff failed.
function M.start(ref)
    -- All at once, as the diff takes the longest.
    local files, merge_base, repo = git.changed_files(ref), git.merge_base(ref), git.repo()
    local reason, diff_reason
    merge_base, reason = merge_base()
    files, diff_reason = files()
    if not merge_base then
        -- Git only says why when it is not the histories, like for a ref that does not exist.
        warn(reason and "Cannot review against " .. ref or "HEAD shares no history with " .. ref, reason)
        return false
    elseif not files then
        warn("git diff " .. ref .. " failed", diff_reason)
        return false
    end
    clear()
    M.ref, M.merge_base = ref, merge_base
    M.head, M.source, M.prefix, M.git_dir = repo()
    set_files(files)
    return true
end

M.stop = clear

function M.active()
    return M.ref ~= nil
end

-- Reloads the changed files from git, false when the diff failed.
function M.load()
    -- All at once, as the diff takes the longest.
    local files, merge_base, repo = git.changed_files(M.ref), git.merge_base(M.ref), git.repo()
    local reason
    files, reason = files()
    if not files then
        warn("git diff " .. M.ref .. " failed", reason)
        return false
    end
    M.merge_base = merge_base()
    M.head, M.source, M.prefix = repo()
    set_files(files)
    return true
end

return M
