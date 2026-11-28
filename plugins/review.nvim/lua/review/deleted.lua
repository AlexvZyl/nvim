-- Read-only buffers showing deleted files as at the merge base.
local git = require("review.git")
local Buffer = require("review.buffer")
local session = require("review.session")

local M = {}

local PREFIX = "review://"

-- Nil for other buffers.
local function deleted_path(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    return vim.startswith(name, PREFIX) and name:sub(#PREFIX + 1) or nil
end

-- By path.
local function deleted_buffers()
    local by_path = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local path = deleted_path(bufnr)
        if path then
            by_path[path] = bufnr
        end
    end
    return by_path
end

local function load_lines(bufnr, path)
    local head_content, base_content = git.show(path, "HEAD", session.merge_base)
    local lines = vim.split(base_content or "", "\n", { plain = true })
    if lines[#lines] == "" and #lines > 1 then
        table.remove(lines)
    end
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
    vim.api.nvim_buf_clear_namespace(bufnr, Buffer.namespace, 0, -1)
    -- In HEAD when only deleted locally.
    Buffer.sign(bufnr, 1, #lines, head_content ~= nil, "Delete")
end

function M.open(path)
    local bufnr = deleted_buffers()[path]
    if bufnr then
        return bufnr
    end
    -- Not bufadd, whose options reset when first shown.
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, PREFIX .. path)
    load_lines(bufnr, path)
    vim.bo[bufnr].filetype = vim.filetype.match({ filename = path, buf = bufnr }) or ""
    return bufnr
end

-- After a reload: replaces files no longer deleted, and reloads the rest when HEAD moved.
function M.refresh(moved)
    for path, bufnr in pairs(deleted_buffers()) do
        local file = session.by_repo_path[session.cwd_prefix .. path]
        if not (file and file.is_deleted) then
            for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
                vim.api.nvim_win_call(winid, function()
                    vim.cmd.edit(vim.fn.fnameescape(path))
                end)
            end
            vim.api.nvim_buf_delete(bufnr, { force = true })
        elseif moved then
            load_lines(bufnr, path)
        end
    end
end

function M.wipe()
    for _, bufnr in pairs(deleted_buffers()) do
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end
end

-- A buffer's path from the cwd, also for deleted files.
function M.path(bufnr)
    return deleted_path(bufnr) or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
end

return M
