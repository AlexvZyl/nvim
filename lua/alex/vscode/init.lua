-- Native keymaps that map to vscode
require('alex.keymaps').vscode()

local n, i, v, t = 'n', 'i', 'v', 't'
local ex_t = { n, i, v }
local ex_i = { n, v, t }
local n_v = { n, v }
local n_i = { n, i }
local all = { n, i, v, t }

local keymap = vim.keymap.set
local default_settings = { noremap = true, silent = true }
local allow_remap = { noremap = false, silent = true }

-- Utils
keymap(n, "ff", "<Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>", default_settings)
keymap(n, "fs", "<Cmd>call VSCodeNotify('workbench.action.findInFiles')<CR>", default_settings)
keymap(n, "<C-t>", "<Cmd>call VSCodeNotify('workbench.action.openRecent')<CR>", default_settings)

-- UI
keymap(n, "<space>f", "<Cmd>call VSCodeNotify('workbench.view.explorer')<CR>", default_settings)
keymap(n, "<space>b", "<Cmd>call VSCodeNotify('workbench.action.toggleSidebarVisibility')<CR>", default_settings)
keymap(n, "<space>t", "<Cmd>call VSCodeNotify('workbench.action.terminal.toggleTerminal')<CR>", default_settings)
keymap(n, "<space>g", "<Cmd>call VSCodeNotify('workbench.view.scm')<CR>", default_settings)
keymap(n, "<space>p", "<Cmd>call VSCodeNotify('workbench.action.togglePanel')<CR>", default_settings)

-- Windows/Editors
keymap(n, "H", "<Cmd>call VSCodeNotify('workbench.action.previousEditor')<CR>", default_settings)
keymap(n, "L", "<Cmd>call VSCodeNotify('workbench.action.nextEditor')<CR>", default_settings)
keymap(n, "Q", "<Cmd>call VSCodeNotify('workbench.action.closeActiveEditor')<CR>", default_settings)
keymap(n, "<C-j>", "<Cmd>call VSCodeNotify('workbench.action.navigateDown')<CR>", default_settings)
keymap(n, "<C-k>", "<Cmd>call VSCodeNotify('workbench.action.navigateUp')<CR>", default_settings)
keymap(n, "<C-h>", "<Cmd>call VSCodeNotify('workbench.action.navigateLeft')<CR>", default_settings)
keymap(n, "<C-l>", "<Cmd>call VSCodeNotify('workbench.action.navigateRight')<CR>", default_settings)

-- Editing
keymap(n_i, "<C-z>", "<Cmd>call VSCodeNotify('undo')<CR>", default_settings)
keymap(n_i, "<C-y>", "<Cmd>call VSCodeNotify('redo')<CR>", default_settings)

-- Termnial
keymap(all, "<M-k>", "<Cmd>call VSCodeNotify('workbench.action.terminal.resizePaneDown')<CR>", default_settings)
keymap(all, "<M-j>", "<Cmd>call VSCodeNotify('workbench.action.terminal.resizePaneDown')<CR>", default_settings)

keymap(all, "<C-s>", "<Cmd>call VSCodeNotify('workbench.action.files.save')<CR>", default_settings)

-- LSP
keymap(n, "<C-t>", "<Cmd>call VSCodeNotify('workbench.action.openRecent')<CR>", default_settings)
keymap(n, "RR", "<Cmd>call VSCodeNotify('editor.action.rename')<CR>", default_settings)
keymap(n, "]e", "<Cmd>call VSCodeNotify('editor.action.marker.next')<CR>", default_settings)
keymap(n, "[e", "<Cmd>call VSCodeNotify('editor.action.marker.prev')<CR>", default_settings)
keymap(n, "<space>d", "<Cmd>call VSCodeNotify('workbench.action.closePanel')<CR>", default_settings)
