local M = {}

function M.merge(table1, table2)
    if table1 == table2 == nil then return {} end
    if table1 == nil then
        return table2
    elseif table2 == nil then
        return table1
    end
    return vim.tbl_deep_extend('force', table1, table2)
end
M = M.merge(M, require 'alex.utils.chars')
M = M.merge(M, require 'alex.utils.filesystem')
M = M.merge(M, require 'alex.utils.theme')

function M.length(table)
    local count = 0
    for _, _ in ipairs(table) do
        count = count + 1
    end
    return count
end

-- Get the current buffer's filetype.
function M.get_current_filetype() return vim.api.nvim_buf_get_option(0, 'filetype') end

-- Get the current buffer's type.
function M.get_current_buftype() return vim.api.nvim_buf_get_option(0, 'buftype') end

function M.current_buffer_modified() return vim.api.nvim_buf_get_option(0, 'modified') end

function M.current_window_floating() return vim.api.nvim_win_get_config(0).relative ~= '' end

function M.current_buffer_modifiable()
    local buftype = vim.api.nvim_buf_get_option(0, 'buftype')
    if buftype == 'nofile' or buftype == 'prompt' then return false end
    if vim.api.nvim_buf_get_option(0, 'modified') then return false end
    return true
end

-- Get the buffer's filename.
function M.get_current_filename()
    local bufname = vim.api.nvim_buf_get_name(0)
    return bufname ~= '' and vim.fn.fnamemodify(bufname, ':t') or ''
end

function M.get_current_icon()
    local ft = M.get_current_filetype()
    local I = require 'nvim-web-devicons'
    -- local color = I.get_icon_color_by_filetype(ft)
    local icon = I.get_icon_by_filetype(ft)
    return icon
end

function M.parent_folder()
    local current_buffer = vim.api.nvim_get_current_buf()
    local current_file = vim.api.nvim_buf_get_name(current_buffer)
    local parent = vim.fn.fnamemodify(current_file, ':h:t')
    if parent == '.' then return '' end
    return parent .. '/'
end

function M.get_native_lsp()
    local buf_ft = M.get_current_filetype()
    local clients = vim.lsp.get_active_clients()
    if next(clients) == nil then return '' end
    local current_clients = ''
    for _, client in ipairs(clients) do
        local filetypes = client.config.filetypes
        if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
            current_clients = current_clients .. client.name .. ' '
        end
    end
    return current_clients
end

-- Display the difference in commits between local and head.
local Job = require 'plenary.job'
function M.get_git_compare()
    -- Get the path of the current directory.
    local curr_dir = vim.api.nvim_buf_get_name(0):match('(.*' .. '/' .. ')')

    -- Run job to get git.
    local result = Job:new({
        command = 'git',
        cwd = curr_dir,
        args = { 'rev-list', '--left-right', '--count', 'HEAD...@{upstream}' },
    })
        :sync(100)[1]

    -- Process the result.
    if type(result) ~= 'string' then return '' end
    local ok, ahead, behind = pcall(string.match, result, '(%d+)%s*(%d+)')
    if not ok then return '' end

    -- No file, so no git.
    if M.get_current_buftype() == 'nofile' then return '' end
    local string = ''
    if behind ~= '0' then string = string .. '󱦳' .. behind end
    if ahead ~= '0' then string = string .. '󱦲' .. ahead end
    return string
end

function M.is_recording() return vim.fn.reg_recording() ~= '' end

function M.get_recording_icon()
    if M.is_recording() then
        return '  '
    else
        return ''
    end
end

return M
