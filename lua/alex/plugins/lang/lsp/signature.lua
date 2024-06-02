local U = require 'alex.utils'

local cfg = {
    wrap = false,
    doc_lines = 0,
    max_width = 200,
    bind = true,
    handler_opts = { border = U.get_border_chars 'lsp' },
    hint_enable = false,
    floating_window = false,
    toggle_key = '<C-\\>',
    --toggle_key_flip_floatwin_setting = true,
}

require('lsp_signature').setup(cfg)
