local icons = require 'nvim-web-devicons'

--local get_icon = icons.get_icon_color
--local go_icon, go_color = get_icon('main.go', 'go')

local go_icon = {
    icon = '',
    color = '#519aba',
    name = 'go',
}

-- Why is this not working???
icons.setup {
    strict = true,
    override_by_filename = {
        ['go.mod'] = go_icon,
        ['go.sum'] = go_icon,
    },
}
