require 'alex.lazyload.bootstrap'
require 'alex.lazyload.events'

-- Load events
vim.api.nvim_create_autocmd('User', {
    callback = function(_)
        vim.api.nvim_exec_autocmds('User', {
            pattern = 'NvimStartupDone',
        })
    end,
    pattern = 'DashboardLoaded',
    once = true,
})
-- This will no longer work if Dashboard starts to set the value
vim.api.nvim_create_autocmd('BufModifiedSet', {
    callback = function(_)
        vim.api.nvim_exec_autocmds('User', {
            pattern = 'NvimStartupDone',
        })
    end,
    once = true,
})

-- Load plugins
local U = require 'alex.utils'
local plugins = require 'alex.lazyload.plugins'
local opts = {
    ui = { border = U.border_chars_outer_thin },
    defaults = { lazy = false },
    checker = {
        notify = false,
        enabled = true,
    },
}
require('lazy').setup(plugins, opts)
