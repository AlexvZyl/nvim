-- Read-only buffers of deleted files as they were at the merge base, all marked deleted, so the cursor can go
-- through them.
local git = require("review.git")
local render = require("review.render")
local session = require("review.session")

local M = {}

local PREFIX = "review://"

-- The path of the deleted file the buffer shows, nil for other buffers.
local function deleted_path(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    return vim.startswith(name, PREFIX) and name:sub(#PREFIX + 1) or nil
end

-- The buffers of deleted files, by their path.
local function buffers()
    local found = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local path = deleted_path(buf)
        if path then
            found[path] = buf
        end
    end
    return found
end

local function fill(buf, path)
    local lines = vim.split(git.show(session.merge_base, path) or "", "\n", { plain = true })
    if lines[#lines] == "" and #lines > 1 then
        table.remove(lines)
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, vim.api.nvim_create_namespace("review"), 0, -1)
    -- Still in HEAD when only deleted locally.
    render.sign(buf, 1, #lines, git.show("HEAD", path) ~= nil, "Delete")
end

function M.open(path)
    local buf = buffers()[path]
    if buf then
        return buf
    end
    -- Not with bufadd, whose options are reset when it is first shown in a window.
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, PREFIX .. path)
    fill(buf, path)
    vim.bo[buf].filetype = vim.filetype.match({ filename = path, buf = buf }) or ""
    return buf
end

-- After git changed what is reviewed: buffers of files no longer deleted make way for the file, the others are
-- rebuilt when what they show moved.
function M.refresh(moved)
    for path, buf in pairs(buffers()) do
        local file = session.by_key[session.prefix .. path]
        if not (file and file.deleted) then
            for _, win in ipairs(vim.fn.win_findbuf(buf)) do
                vim.api.nvim_win_call(win, function()
                    vim.cmd.edit(vim.fn.fnameescape(path))
                end)
            end
            vim.api.nvim_buf_delete(buf, { force = true })
        elseif moved then
            fill(buf, path)
        end
    end
end

function M.wipe()
    for _, buf in pairs(buffers()) do
        vim.api.nvim_buf_delete(buf, { force = true })
    end
end

-- The path of a file from its buffer, also for a deleted file's.
function M.path(buf)
    return deleted_path(buf) or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
end

return M
