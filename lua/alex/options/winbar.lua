vim.opt.winbar = [[%{%v:lua.require('alex.options.winbar').winbar()%}]]

local M = {}

function M.winbar()
    local U = require 'alex.utils'
    local icon = U.get_current_icon()
    if icon == nil then return '' end
    return '  ' .. icon .. ' ' .. U.parent_folder() .. U.get_current_filename()
end

return M
