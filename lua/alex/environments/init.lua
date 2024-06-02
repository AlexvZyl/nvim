local M = {}

function M.should_setup()
    -- Editor specific configs.
    if vim.g.vscode then
        require('alex.environments.vscode')
        return false
    end

    -- Setup environment variables.
    local U = require('alex.utils.filesystem')
    local env_file = os.getenv('HOME') .. '/.private/nvim_env.lua'
    if U.file_exists(env_file) then vim.cmd('luafile ' .. env_file) end

    -- This makes neovim load faster.
    vim.loader.enable()

    if vim.g.neovide then
        require('alex.environments.neovide')
        return true
    end

    -- TODO: Check if we are in wezterm specifically.
    require('alex.environments.wezterm')
    return true
end

return M
