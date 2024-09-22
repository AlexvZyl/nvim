local C = require("alex.utils.chars")
local U = require("alex.utils.neovim")

-- Important to place this before loading plugins.
vim.g.mapleader = " "

vim.opt.showmode = false
vim.opt.clipboard:append("unnamedplus")
vim.opt.swapfile = false
vim.opt.mouse = "a"
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

if not U.is_default() then
    vim.opt.fillchars = {
        horiz = C.bottom_thin,
        horizup = C.bottom_thin,
        horizdown = C.right_thick,
        vert = C.right_thick,
        vertleft = C.right_thick,
        vertright = C.right_thick,
        verthoriz = C.right_thick,
    }
else
    vim.opt.fillchars = {
        eob = " ",
        diff = "╱",
    }
end

-- Numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"

-- Cursor
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number"

-- Windows
vim.opt.winblend = 0
vim.opt.pumblend = 0
vim.opt.pumheight = 10

-- Theme
vim.opt.background = "dark"

-- Default new window to vertical split (this messes up debugger windows).
-- vim.api.nvim_command('autocmd WinNew * wincmd H')

vim.cmd("filetype plugin indent on")

-- Automatically remove trailing whitespace.
vim.cmd([[
    match ExtraWhitespace /\s\+$/
    autocmd BufWritePre * %s/\s\+$//e
]])
