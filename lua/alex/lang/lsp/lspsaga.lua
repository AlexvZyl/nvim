local U = require 'alex.utils'

local ui = {
    border = U.get_border_chars 'lsp',
    winblend = 0,
    title = false,
    diagnostic = '  ',
}

local lightbulb = {
    enable = false,
}

local definition = {
    edit = '<C-e>',
    vsplit = '<C-v>',
    split = '<C-h>',
    quit = '<C-q>',
}

local winbar = {
    enable = false,
    folder_level = 1,
    show_file = true,
    separator = '  ',
}

local diagnostic = {
    max_show_width = 0.5,
    show_code_action = false,
    on_insert = false,
    show_source = false,
    border_follow = false,
    text_hl_follow = true,
    extend_relatedInformation = true,
}

local hover = {
    max_width = 0.5,
}

require('lspsaga').setup {
    lightbulb = lightbulb,
    ui = ui,
    definition = definition,
    symbol_in_winbar = winbar,
    diagnostic = diagnostic,
    hover = hover,
}

require('alex.keymaps').lspsaga()
