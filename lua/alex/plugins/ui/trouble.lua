local U = require 'alex.utils'

require('trouble').setup {
    padding = true,
    height = 11,
    auto_refresh = true,
    position = 'bottom',
    use_diagnostic_signs = true,
    signs = U.diagnostic_signs,
    auto_preview = false,
}

require('alex.keymaps').trouble()
