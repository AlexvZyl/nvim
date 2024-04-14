local u = require 'alex.utils'

-- Important to place this before loading plugins.
vim.g.mapleader = ' '

vim.opt.showmode = false
vim.opt.clipboard:append 'unnamedplus'
vim.opt.swapfile = false
vim.opt.mouse = 'a'
vim.opt.hlsearch = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.textwidth = 0

vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.wrap = false

vim.opt.cmdheight = 0
vim.g.VM_set_statusline = 0
vim.g.VM_silent_exit = 1

vim.opt.fillchars = {
    horiz = u.bottom_thin,
    horizup = u.bottom_thin,
    horizdown = ' ',
    vert = u.right_thick,
    vertleft = u.right_thick,
    vertright = u.right_thick,
    verthoriz = u.right_thick,
    eob = ' ',
    diff = '╱',
}

-- Numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = 'yes'

-- Cursor
vim.opt.cursorline = true
vim.opt.cursorlineopt = 'number'

-- Windows
vim.opt.winblend = 0
vim.opt.pumblend = 0
vim.opt.pumheight = 10

-- Theme
vim.opt.background = 'dark'

-- Default new window to vertical split (this messes up debugger windows).
-- vim.api.nvim_command('autocmd WinNew * wincmd H')

vim.cmd 'filetype plugin indent on'

-- Automatically remove trailing whitespace.
vim.cmd [[
    match ExtraWhitespace /\s\+$/
    autocmd BufWritePre * %s/\s\+$//e
]]

-- Enable blinking for wezterm
vim.opt.guicursor = 'i:ver20-blinkon1,a:blinkon1'


-- Statuscolumn was added in 0.9.
if vim.version.major == 0 and vim.version.minor < 9 then return end

--No separator.
--vim.opt.numberwidth = 4
--vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s"

-- With sepaartor.
--vim.opt.numberwidth = 6
--vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s▎ "

-- Signs first, right aligned relative number
vim.opt.numberwidth = 5
vim.opt.statuscolumn = ' %s%=%{v:relnum?v:relnum:v:lnum}%#WinSeparator#  '
--No separator.
--vim.opt.numberwidth = 4
--vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s"

-- With sepaartor.
--vim.opt.numberwidth = 6
--vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s▎ "

-- Signs first, right aligned relative number
vim.opt.numberwidth = 5
vim.opt.statuscolumn = ' %s%=%{v:relnum?v:relnum:v:lnum}%#WinSeparator#  '
