local CMP = require('cmp')
local U = require('alex.utils')

-- UI
local cmdline_window = {
    completion = CMP.config.window.bordered({
        winhighlight = 'Normal:Pmenu,FloatBorder:SpecialCmpBorder,Search:None',
        scrollbar = true,
        border = U.get_border_chars('cmdline'),
        col_offset = -4,
        side_padding = 0,
    }),
}

-- Source
local cmdline = {
    window = cmdline_window,
    mapping = CMP.mapping.preset.cmdline(),
    sources = CMP.config.sources({
        { name = 'cmdline' },
        { name = 'path' },
    }),
}

CMP.setup.cmdline({ ':', ':!' }, cmdline)
