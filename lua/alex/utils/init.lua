local M = require("alex.utils.lua")

M = M.merge(M, require("alex.utils.chars"))
M = M.merge(M, require("alex.utils.neovim"))
M = M.merge(M, require("alex.utils.git"))
M = M.merge(M, require("alex.utils.colors"))

return M
