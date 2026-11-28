-- Read-only buffers showing deleted files as at the merge base.
local git = require("review.git")
local draw = require("review.draw")
local session = require("review.session")

local M = {}

local PREFIX = "review://"

-- Nil for other buffers.
local function deleted_path(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    return vim.startswith(name, PREFIX) and name:sub(#PREFIX + 1) or nil
end

-- By path.
local function deleted_buffers()
    local by_path = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local path = deleted_path(buf)
        if path then
            by_path[path] = buf
        end
    end
    return by_path
end

local function load_lines(buf, path)
    local head_content, base_content = git.show(path, "HEAD", session.merge_base)
    local lines = vim.split(base_content or "", "\n", { plain = true })
    if lines[#lines] == "" and #lines > 1 then
        table.remove(lines)
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, draw.namespace, 0, -1)
    -- In HEAD when only deleted locally.
    draw.sign(buf, 1, #lines, head_content ~= nil, "Delete")
end

function M.open(path)
    local buf = deleted_buffers()[path]
    if buf then
        return buf
    end
    -- Not bufadd, whose options reset when first shown.
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, PREFIX .. path)
    load_lines(buf, path)
    vim.bo[buf].filetype = vim.filetype.match({ filename = path, buf = buf }) or ""
    return buf
end

-- After a reload: replaces files no longer deleted, and reloads the rest when HEAD moved.
function M.refresh(moved)
    for path, buf in pairs(deleted_buffers()) do
        local file = session.by_repo_path[session.cwd_prefix .. path]
        if not (file and file.is_deleted) then
            for _, win in ipairs(vim.fn.win_findbuf(buf)) do
                vim.api.nvim_win_call(win, function()
                    vim.cmd.edit(vim.fn.fnameescape(path))
                end)
            end
            vim.api.nvim_buf_delete(buf, { force = true })
        elseif moved then
            load_lines(buf, path)
        end
    end
end

function M.wipe()
    for _, buf in pairs(deleted_buffers()) do
        vim.api.nvim_buf_delete(buf, { force = true })
    end
end

-- A buffer's path from the cwd, also for deleted files.
function M.path(buf)
    return deleted_path(buf) or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
end

return M
