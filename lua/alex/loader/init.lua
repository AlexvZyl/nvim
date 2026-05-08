require("alex.loader.bootstrap")

local plugins = require("alex.loader.plugins")

local opts = {
    ui = { border = "rounded", backdrop = 100 },
    defaults = { lazy = false }, -- TODO: Is this smart?
    checker = {
        notify = false,
        enabled = true,
    },
}

require("lazy").setup(plugins, opts)
