local U = require 'alex.utils'

vim.wo.statuscolumn = ''
vim.cmd 'set nocursorline'
vim.cmd 'setlocal winbar=\\ \\ \\ Diagnostics'

U.link_hl('WinBar', 'TroubleWinbar')
U.link_hl('WinBarNC', 'TroubleWinbar')
