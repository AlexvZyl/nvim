require("alex.managers.lazy.bootstrap")
require("alex.managers.lazy.events")

local U = require("alex.utils.chars")
local plugins = require("alex.managers.lazy.plugins")

local opts = {
    ui = { border = U.border_chars_outer_thin },
    defaults = { lazy = false },
    checker = {
        notify = false,
        enabled = true,
    },
}

require("lazy").setup(plugins, opts)
