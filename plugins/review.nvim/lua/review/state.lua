local session = require("review.session")

local M = {}

local function empty()
    return { reviewed = {}, seen = {}, undo = {}, redo = {} }
end

-- Blob each file was reviewed at, files already seen and the undo history.
local data = empty()

local function path()
    local name = (session.source .. ".." .. session.ref):gsub("/", "%%")
    return session.git_dir .. "/review/" .. name .. ".json"
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
    local decoded, saved = pcall(vim.json.decode, ok and table.concat(lines, "\n") or "")
    saved = decoded and type(saved) == "table" and saved or {}
    -- Without saved state nothing is new yet.
    local seen = type(saved.seen) == "table" and saved.seen
        or vim.tbl_map(function(file)
            return file.key
        end, session.files)
    data = {
        reviewed = type(saved.reviewed) == "table" and saved.reviewed or {},
        seen = {},
        undo = valid_history(saved.undo),
        redo = valid_history(saved.redo),
    }
    for _, key in ipairs(seen) do
        data.seen[key] = true
    end
end

function M.save()
    local file = path()
    local encoded = vim.json.encode({
        reviewed = as_dict(data.reviewed),
        seen = vim.tbl_keys(data.seen),
        undo = data.undo,
        redo = data.redo,
    })
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
    vim.fn.writefile({ encoded }, file .. ".tmp")
    vim.uv.fs_rename(file .. ".tmp", file)
end

function M.reset()
    os.remove(path())
    data = empty()
end

local function blob(key)
    return session.blobs[key] or ""
end

function M.pending(key)
    return data.reviewed[key] ~= blob(key)
end

function M.changed(key)
    local reviewed = data.reviewed[key]
    return reviewed ~= nil and reviewed ~= blob(key)
end

function M.new(key)
    return not data.seen[key]
end

local function capture(keys, cursor)
    local changes = {}
    for _, key in ipairs(keys) do
        changes[key] = { reviewed = data.reviewed[key] or false, seen = data.seen[key] or false }
    end
    return { changes = changes, cursor = cursor }
end

function M.review(keys, cursor)
    table.insert(data.undo, capture(keys, cursor))
    data.redo = {}
    for _, key in ipairs(keys) do
        data.reviewed[key] = blob(key)
        data.seen[key] = true
    end
    M.save()
end

function M.clear(key)
    data.reviewed[key] = nil
    data.seen[key] = true
    M.save()
end

local function restore(from, to, cursor)
    if #data[from] == 0 then
        return nil
    end
    -- Skip entries that no longer change anything.
    local entry, changed
    repeat
        entry = table.remove(data[from])
        table.insert(data[to], capture(vim.tbl_keys(entry.changes), cursor))
        for key, change in pairs(entry.changes) do
            changed = changed
                or (data.reviewed[key] or false) ~= change.reviewed
                or (data.seen[key] or false) ~= change.seen
            data.reviewed[key] = change.reviewed or nil
            data.seen[key] = change.seen or nil
        end
    until changed or #data[from] == 0
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
