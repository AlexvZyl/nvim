require("alex.loader.bootstrap")

local plugins = require("alex.loader.plugins")

local opts = {
    ui = { border = "rounded" },
    defaults = { lazy = false },
    checker = {
        notify = false,
        enabled = true,
    },
}

require("lazy").setup(plugins, opts)
