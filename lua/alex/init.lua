-- Setup environment
local U = require 'alex.utils'
local env_file = os.getenv 'HOME' .. '/.private/nvim_env.lua'
if U.file_exists(env_file) then vim.cmd('luafile ' .. env_file) end

-- Editor specific configs.
if vim.g.vscode then
    require 'alex.editors.vscode'
    return
end
if vim.g.neovide then require 'alex.editors.neovide' end

-- This makes neovim load faster
vim.loader.enable()

-- Order is important
require 'alex.options'
require 'alex.lazyload'
require('alex.keymaps').init()
