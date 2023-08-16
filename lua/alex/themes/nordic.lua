require('nordic').load {
    reduced_blue = true,
    cursorline = {
        theme = 'dark',
        bold = false,
        bold_number = true,
        blend = 0.7,
    },
}

require('lualine').setup {
    options = { theme = 'nordic' },
}
