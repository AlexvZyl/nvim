local session = require("review.session")

local M = {}

-- The saved JSON, by repo path: reviewed blob hashes, seen files, and undo/redo snapshots.
local saved = { reviewed = {}, seen = {}, undo = {}, redo = {} }

local function state_file()
    local name = (session.branch .. ".." .. session.base_ref):gsub("/", "%%")
    return session.git_dir .. "/review/" .. name .. ".json"
end

-- Tolerates broken or old saved state.
function M.load()
    local ok, decoded = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(state_file()), "\n"))
    end)
    decoded = ok and type(decoded) == "table" and decoded or {}
    local function valid_snapshots(stack)
        return vim.tbl_filter(function(snapshot)
            return type(snapshot) == "table" and type(snapshot.changes) == "table"
        end, type(stack) == "table" and stack or {})
    end
    -- Without saved state nothing is unseen.
    local seen = type(decoded.seen) == "table" and decoded.seen
        or vim.tbl_map(function(file)
            return file.repo_path
        end, session.files)
    local reviewed = type(decoded.reviewed) == "table" and decoded.reviewed or {}
    saved = { reviewed = reviewed, seen = {}, undo = valid_snapshots(decoded.undo), redo = valid_snapshots(decoded.redo) }
    for _, repo_path in ipairs(seen) do
        saved.seen[repo_path] = true
    end
end

function M.save()
    local path = state_file()
    -- An empty table encodes as a list, which loads the same.
    local encoded = vim.json.encode({ reviewed = saved.reviewed, seen = vim.tbl_keys(saved.seen), undo = saved.undo, redo = saved.redo })
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({ encoded }, path .. ".tmp")
    vim.uv.fs_rename(path .. ".tmp", path)
end

function M.reset()
    os.remove(state_file())
    M.load()
end

-- Empty when not in HEAD.
local function head_hash(repo_path)
    return session.head_hashes()[repo_path] or ""
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
    M.save()
end

-- Clears a file's dot: unreviewed and seen.
function M.mark_opened(repo_path)
    saved.reviewed[repo_path] = nil
    saved.seen[repo_path] = true
    M.save()
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
    M.save()
    return snapshot_restored.cursor, vim.tbl_keys(snapshot_restored.changes)
end

function M.undo(cursor_line)
    return restore("undo", "redo", cursor_line)
end

function M.redo(cursor_line)
    return restore("redo", "undo", cursor_line)
end

return M
