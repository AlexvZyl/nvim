require("alex.plugins.managers.lazy.bootstrap")

local U = require("alex.utils.chars")
local plugins = require("alex.plugins.managers.lazy.plugins")

local opts = {
    ui = { border = U.border_chars_outer_thin },
    defaults = { lazy = false },
    checker = {
        notify = false,
        enabled = true,
    },
}

require("lazy").setup(plugins, opts)
