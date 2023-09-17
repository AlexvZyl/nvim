local CMP = require 'cmp'
local U = require 'alex.utils'

-- UI
local cmdline_window = {
    completion = CMP.config.window.bordered {
        scrollbar = true,
        border = U.get_border_chars 'cmdline',
        col_offset = -4,
        side_padding = 0,
    },
}

-- Source
local cmdline = {
    window = cmdline_window,
    mapping = CMP.mapping.preset.cmdline(),
    sources = CMP.config.sources {
        { name = 'path' },
        { name = 'cmdline' },
    },
}

CMP.setup.cmdline(':', cmdline)
