local git = require("alex.native.review.git")
local session = require("alex.native.review.session")

local M = {}

local function path()
    local name = (session.source .. ".." .. session.ref):gsub("/", "%%")
    return git.git_dir() .. "/review/" .. name .. ".json"
end

local function valid_history(stack)
    return vim.tbl_filter(function(entry)
        return type(entry) == "table" and type(entry.changes) == "table"
    end, type(stack) == "table" and stack or {})
end

local function as_dict(tbl)
    return next(tbl) and tbl or vim.empty_dict()
end

function M.load()
    local ok, lines = pcall(vim.fn.readfile, path())
    local decoded, data = pcall(vim.json.decode, ok and table.concat(lines, "\n") or "")
    data = decoded and type(data) == "table" and data or {}
    local seen = type(data.seen) == "table" and data.seen
        or vim.tbl_map(function(file)
            return file.key
        end, session.files)
    session.state = {
        reviewed = type(data.reviewed) == "table" and data.reviewed or {},
        seen = {},
        undo = valid_history(data.undo),
        redo = valid_history(data.redo),
    }
    for _, key in ipairs(seen) do
        session.state.seen[key] = true
    end
end

function M.save()
    local file = path()
    local state = session.state
    local data = {
        reviewed = as_dict(state.reviewed),
        seen = vim.tbl_keys(state.seen),
        undo = state.undo,
        redo = state.redo,
    }
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
    vim.fn.writefile({ vim.json.encode(data) }, file .. ".tmp")
    vim.uv.fs_rename(file .. ".tmp", file)
end

function M.reset()
    os.remove(path())
    session.state = { reviewed = {}, seen = {}, undo = {}, redo = {} }
end

function M.blob(key)
    return session.blobs[key] or ""
end

function M.pending(key)
    return session.state.reviewed[key] ~= M.blob(key)
end

function M.changed(key)
    local reviewed = session.state.reviewed[key]
    return reviewed ~= nil and reviewed ~= M.blob(key)
end

function M.new(key)
    return not session.state.seen[key]
end

local function capture(keys, cursor)
    local state = session.state
    local changes = {}
    for _, key in ipairs(keys) do
        changes[key] = { reviewed = state.reviewed[key] or false, seen = state.seen[key] or false }
    end
    return { changes = changes, cursor = cursor }
end

function M.review(keys, cursor)
    local state = session.state
    table.insert(state.undo, capture(keys, cursor))
    state.redo = {}
    for _, key in ipairs(keys) do
        state.reviewed[key] = M.blob(key)
        state.seen[key] = true
    end
    M.save()
end

function M.clear(key)
    session.state.reviewed[key] = nil
    session.state.seen[key] = true
    M.save()
end

local function restore(from, to, cursor)
    local state = session.state
    if #state[from] == 0 then
        return nil
    end
    local entry, changed
    repeat
        entry = table.remove(state[from])
        table.insert(state[to], capture(vim.tbl_keys(entry.changes), cursor))
        for key, change in pairs(entry.changes) do
            changed = changed
                or (state.reviewed[key] or false) ~= change.reviewed
                or (state.seen[key] or false) ~= change.seen
            state.reviewed[key] = change.reviewed or nil
            state.seen[key] = change.seen or nil
        end
    until changed or #state[from] == 0
    M.save()
    return entry.cursor
end

function M.undo(cursor)
    return restore("undo", "redo", cursor)
end

function M.redo(cursor)
    return restore("redo", "undo", cursor)
end

return M
