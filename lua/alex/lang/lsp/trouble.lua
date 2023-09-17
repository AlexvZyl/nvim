local U = require 'alex.utils'

require('trouble').setup {
    padding = true,
    height = 11,
    position = 'bottom',
    use_diagnostic_signs = true,
    signs = U.diagnostic_signs,
    auto_preview = false,
}

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    command = 'TroubleRefresh',
})
