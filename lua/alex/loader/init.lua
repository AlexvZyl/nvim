require("alex.loader.bootstrap")

local plugins = require("alex.loader.plugins")

local opts = {
    ui = { border = "rounded" },
    defaults = { lazy = false }, -- TODO: Is this smart?
    checker = {
        notify = true,
        enabled = true,
    },
}

require("lazy").setup(plugins, opts)
