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

local C = require 'nordic.colors'
vim.cmd('highlight LspSignatureActiveParameter guibg=' .. C.bg_float .. ' guisp=' .. C.white0)
