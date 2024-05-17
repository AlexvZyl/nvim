vim.opt.winbar = nil

local M = {}

M.winbar_filetype_exclude = {
  --"help",
  "dashboard",
  "NvimTree",
  "Trouble",
  "Outline",
}

local excludes = function()
  if vim.tbl_contains(M.winbar_filetype_exclude, vim.bo.filetype) then
    return true
  end
  return false
end

function M.get_winbar()
    if excludes() then
        return
    end

    local U = require 'alex.utils'
    local icon = U.get_current_icon()
    if icon == nil then icon = '' end

    local mod_icon = ''
    if U.current_buffer_modified() then
        mod_icon = ' ●'
    elseif U.current_buffer_modifiable() then
        mod_icon = ' '
    end

    vim.opt_local.winbar = '  ' .. icon .. ' ' .. U.parent_folder() .. U.get_current_filename() .. mod_icon
end

vim.api.nvim_create_autocmd({ "BufModifiedSet", "BufWinEnter", "BufFilePost", "BufWritePost" }, {
  callback = function()
    require("alex.options.winbar").get_winbar()
  end,
})

return M
