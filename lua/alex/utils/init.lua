local M = require('alex.utils.lua')

M = M.merge(M, require('alex.utils.chars'))
M = M.merge(M, require('alex.utils.filesystem'))
M = M.merge(M, require('alex.utils.neovim'))
M = M.merge(M, require('alex.utils.git'))

return M
