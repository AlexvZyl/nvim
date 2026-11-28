-- File is one changed file in the review, with its line counts and review status.
local config = require("review.config")
local git = require("review.git")
local session = require("review.session")
local state = require("review.state")

local File = {}
File.__index = File

-- Counts are nil for binary files.
function File.new(path, lines_added, lines_removed)
    return setmetatable({
        -- From the cwd.
        path = path,
        -- From the repo root. The state is saved by it, so it does not depend on the cwd.
        repo_path = session.cwd_prefix .. path,
        lines_added_since_merge_base = lines_added,
        lines_removed_since_merge_base = lines_removed,
        -- Its share of the progress %: changed lines, at least 1.
        progress_weight = math.max((lines_added or 0) + (lines_removed or 0), 1),
        is_deleted = (lines_added or 0) == 0 and vim.uv.fs_stat(path) == nil,
        -- { hash, lines_added, lines_removed }, set by File.count_lines_since_review.
        since_review = nil,
    }, File)
end

function File:needs_review()
    return state.needs_review(self.repo_path)
end

function File:changed_after_review()
    return state.changed_after_review(self.repo_path)
end

function File:is_unseen()
    return state.is_unseen(self.repo_path)
end

-- Nil when not reviewed.
function File:reviewed_hash()
    return state.reviewed_hash(self.repo_path)
end

-- Sets since_review on files changed after review, reading every reviewed version with one git process.
function File.count_lines_since_review(files)
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

-- Since review in the since_review view when counted, else since the merge base.
function File:counts_to_show()
    local since_review = config.options.view == "since_review" and self.since_review
    if since_review and since_review.lines_added and since_review.hash == self:reviewed_hash() then
        return since_review.lines_added, since_review.lines_removed
    end
    return self.lines_added_since_merge_base, self.lines_removed_since_merge_base
end

return File
