local git = require("review.git")

-- What is being reviewed. Only this module writes it, the others read it.
local M = {
    -- Ref being reviewed against, nil outside diff mode.
    ref = nil,
    -- Branch being reviewed.
    source = nil,
    merge_base = nil,
    git_dir = nil,
    prefix = "",
    -- Changed files with their path from the cwd, key from the repo root and number of changed lines.
    files = {},
    by_key = {},
    total_changes = 0,
    blobs = {},
}

function M.start(ref)
    M.ref = ref
    M.source = git.branch()
    M.merge_base = git.merge_base(ref)
    M.git_dir = git.git_dir()
end

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
    M.prefix = git.prefix()
    M.files, M.by_key, M.total_changes = files, {}, 0
    for _, file in ipairs(files) do
        file.key = M.prefix .. file.path
        M.by_key[file.key] = file
        M.total_changes = M.total_changes + file.changes
    end
    M.blobs = git.head_blobs()
    return true
end

return M
