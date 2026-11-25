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
    M.blobs = {}
end

clear()

-- False when HEAD has no merge base with the ref.
function M.start(ref)
    local merge_base, repo = git.merge_base(ref), git.repo()
    merge_base = merge_base()
    if not merge_base then
        vim.notify("No merge base with " .. ref, vim.log.levels.ERROR)
        return false
    end
    clear()
    M.ref, M.merge_base = ref, merge_base
    M.head, M.source, M.prefix, M.git_dir = repo()
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
    files = files()
    if not files then
        vim.notify("git diff " .. M.ref .. " failed", vim.log.levels.ERROR)
        return false
    end
    M.merge_base = merge_base()
    M.head, M.source, M.prefix = repo()
    M.files, M.by_key, M.total_changes = files, {}, 0
    for _, file in ipairs(files) do
        file.key = M.prefix .. file.path
        M.by_key[file.key] = file
        M.total_changes = M.total_changes + file.changes
    end
    M.blobs = git.head_blobs(vim.tbl_map(function(file)
        return file.path
    end, files))
    return true
end

return M
