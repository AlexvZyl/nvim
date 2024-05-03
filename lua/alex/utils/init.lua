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

-- Show git status.
function M.diff_source()
    local gitsigns = vim.b.gitsigns_status_dict
    if gitsigns then return { added = gitsigns.added, modified = gitsigns.changed, removed = gitsigns.removed } end
end

-- Get the current buffer's filetype.
function M.get_current_filetype() return vim.api.nvim_buf_get_option(0, 'filetype') end

-- Get the current buffer's type.
function M.get_current_buftype() return vim.api.nvim_buf_get_option(0, 'buftype') end

-- Get the buffer's filename.
function M.get_current_filename()
    local bufname = vim.api.nvim_buf_get_name(0)
    return bufname ~= '' and vim.fn.fnamemodify(bufname, ':t') or ''
end

-- Gets the current buffer's filename with the filetype icon supplied
-- by devicons.
local F = require('lualine.components.filetype'):extend()
Icon_hl_cache = {}
local lualine_require = require 'lualine_require'
local modules = lualine_require.lazy_require {
    highlight = 'lualine.highlight',
    utils = 'lualine.utils.utils',
}

function F:get_current_filetype_icon()
    -- Get setup.
    local icon, icon_highlight_group
    local _, devicons = pcall(require, 'nvim-web-devicons')
    local f_name, f_extension = vim.fn.expand '%:t', vim.fn.expand '%:e'
    f_extension = f_extension ~= '' and f_extension or vim.bo.filetype
    icon, icon_highlight_group = devicons.get_icon(f_name, f_extension)

    -- Fallback settings.
    if icon == nil and icon_highlight_group == nil then
        icon = ''
        icon_highlight_group = 'DevIconDefault'
    end

    -- Set colors.
    --local highlight_color = modules.utils.extract_highlight_colors(icon_highlight_group, 'fg')
    --if highlight_color then
    ---- local default_highlight = self:get_default_hl()
    --local icon_highlight = Icon_hl_cache[highlight_color]
    --if not icon_highlight or not modules.highlight.highlight_exists(icon_highlight.name .. '_normal') then
    --icon_highlight = self:create_hl({ fg = highlight_color }, icon_highlight_group)
    --Icon_hl_cache[highlight_color] = icon_highlight
    --end
    ---- icon = self:format_hl(icon_highlight) .. icon .. default_highlight
    --end

    -- Return the formatted string.
    return icon
end

function F:get_current_filename_with_icon()
    local suffix = ''

    -- Get icon and filename.
    local icon = F.get_current_filetype_icon(self)
    local f_name = M.get_current_filename()

    -- Add readonly icon.
    local readonly = vim.api.nvim_buf_get_option(0, 'readonly')
    local modifiable = vim.api.nvim_buf_get_option(0, 'modifiable')
    local nofile = M.get_current_buftype() == 'nofile'
    if readonly or nofile or not modifiable then suffix = ' ' end

    -- Return the formatted string.
    return icon .. ' ' .. f_name .. suffix
end

function M.get_current_filename_with_icon() return F:get_current_filename_with_icon() end

function M.get_current_icon()
    local I = require 'nvim-web-devicons'
    return I.get_icon_by_filetype(M.get_current_filetype())
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
