local n = 'n'
local i = 'i'
local keymap = vim.keymap.set
local default_settings = { noremap = true, silent = true }

-- Utils
keymap(n, 'ff', "<Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>", default_settings)
keymap(n, 'fs', "<Cmd>call VSCodeNotify('workbench.action.findInFiles')<CR>", default_settings)
keymap(n, '<C-t>', "<Cmd>call VSCodeNotify('workbench.action.openRecent')<CR>", default_settings)
keymap(n, '<Esc>', '<Cmd>noh<CR>', default_settings)
keymap(i, '<Esc>', '<Esc>`^', default_settings)

-- UI
keymap(n, '<space>f', "<Cmd>call VSCodeNotify('workbench.view.explorer')<CR>", default_settings)
keymap(n, '<space>b', "<Cmd>call VSCodeNotify('workbench.action.toggleSidebarVisibility')<CR>", default_settings)
keymap(n, '<space>t', "<Cmd>call VSCodeNotify('workbench.action.terminal.toggleTerminal')<CR>", default_settings)
keymap(n, '<space>g', "<Cmd>call VSCodeNotify('workbench.view.scm')<CR>", default_settings)
keymap(n, '<space>p', "<Cmd>call VSCodeNotify('workbench.action.togglePanel')<CR>", default_settings)
keymap(n, '<space>d', "<Cmd>call VSCodeNotify('workbench.actions.view.problems')<CR>", default_settings)

-- LSP
keymap(n, 'RR', "<Cmd>call VSCodeNotify('editor.action.rename')<CR>", default_settings)
keymap(n, ']e', "<Cmd>call VSCodeNotify('editor.action.marker.next')<CR>", default_settings)
keymap(n, 'e', "<Cmd>call VSCodeNotify('editor.action.marker.next')<CR>", default_settings)
keymap(n, '[e', "<Cmd>call VSCodeNotify('editor.action.marker.prev')<CR>", default_settings)
keymap(n, 'gr', "<Cmd>call VSCodeNotify('editor.action.goToReferences')<CR>", default_settings)

-- Settings
vim.cmd 'set clipboard+=unnamedplus'
