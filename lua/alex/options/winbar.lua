vim.opt.winbar = [[%{%v:lua.require('alex.options.winbar').winbar()%}]]

local M = {}

function M.winbar()
    local U = require 'alex.utils'
    return '  ' .. U.get_current_filename()
end

return M
