local U = require 'alex.utils'

vim.cmd [[
    sign define DiagnosticSignError text= texthl= linehl= numhl=DiagnosticSignError
    sign define DiagnosticSignWarn  text= texthl= linehl= numhl=DiagnosticSignWarn
    sign define DiagnosticSignInfo  text= texthl= linehl= numhl=DiagnosticSignInfo
    sign define DiagnosticSignHint  text=󱤅 texthl= linehl= numhl=DiagnosticSignHint
]]

local config = {
    virtual_text = false,
    signs = true,
    update_on_insert = true,
}

vim.diagnostic.config(config)

require('lspconfig.ui.windows').default_options.border =
    U.get_border_chars 'float'

require 'alex.plugins.lang.lsp.clients'
