vim.opt.winbar = nil

local winbar_filetype_exclude = {
    'dashboard',
    'Trouble',
    'Outline',
    'NvimTree',
}

local excludes = function()
    if vim.tbl_contains(winbar_filetype_exclude, vim.bo.filetype) then return true end
    return false
end

local M = {}

function M.get_winbar()
    if excludes() then return end

    local U = require 'alex.utils'

    if U.current_window_floating() then return end

    local icon = U.current_buffer_icon()
    if icon == nil then icon = '' end

    local mod_icon = ''
    if U.current_buffer_modified() then
        mod_icon = ' ●'
    elseif not U.current_buffer_modifiable() then
        mod_icon = ' '
    end

    vim.opt_local.winbar = '  ' .. icon .. ' ' .. U.current_buffer_parent() .. U.current_buffer_filename() .. mod_icon
end

vim.api.nvim_create_autocmd({ 'BufModifiedSet', 'BufWinEnter', 'BufFilePost', 'BufWritePost' }, {
    callback = function() require('alex.options.winbar').get_winbar() end,
})

return M
