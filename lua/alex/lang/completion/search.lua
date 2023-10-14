local cmp = require 'cmp'
local u = require 'alex.utils'

-- UI
local cmdline_window = {
    completion = cmp.config.window.bordered {
        scrollbar = true,
        border = u.get_border_chars 'search',
        col_offset = -1,
        side_padding = 0,
    },
}

-- Source
local search = {
    window = cmdline_window,
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources {
        { name = 'buffer' },
    },
}

cmp.setup.cmdline({ '/', '?' }, search)
