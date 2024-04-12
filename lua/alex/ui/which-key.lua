local utils = require 'alex.utils'

require('which-key').setup {
    window = {
        border = { '', utils.top_thin, '', '', '', ' ', '', '' },
        margin = { 0, 0, 1, 0 },
        padding = { 0, 0, 0, 0 },
    },
}
vim.cmd 'set timeoutlen =1000'
