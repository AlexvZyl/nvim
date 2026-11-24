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
    local merge_base = git.merge_base(ref)
    if not merge_base then
        vim.notify("No merge base with " .. ref, vim.log.levels.ERROR)
        return false
    end
    clear()
    M.ref = ref
    M.source = git.branch()
    M.merge_base = merge_base
    M.git_dir = git.git_dir()
    return true
end

M.stop = clear

function M.active()
    return M.ref ~= nil
end

-- Reloads the changed files from git, false when the diff failed.
function M.load()
    local files = git.changed_files(M.ref)
    if not files then
        vim.notify("git diff " .. M.ref .. " failed", vim.log.levels.ERROR)
        return false
    end
    M.source = git.branch()
    M.merge_base = git.merge_base(M.ref)
    M.head = git.head()
    M.prefix = git.prefix()
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
