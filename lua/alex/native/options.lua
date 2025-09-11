local C = require("alex.utils.chars")
local U = require("alex.utils.neovim")

-- Important to place this before loading plugins.
vim.g.mapleader = " "

vim.opt.winborder = "rounded"

vim.opt.showmode = false
vim.opt.swapfile = false
vim.opt.mouse = ""
vim.opt.hlsearch = true

vim.opt.clipboard:append("unnamedplus")
vim.g.clipboard = {
    name = "xclip",
    copy = {
        ["+"] = "xclip -selection clipboard",
        ["*"] = "xclip -selection primary",
    },
    paste = {
        ["+"] = "xclip -selection clipboard -o",
        ["*"] = "xclip -selection primary -o",
    },
    cache_enabled = 0,
}

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
vim.opt.showtabline = 0

vim.opt.inccommand = "nosplit"

vim.opt.cmdheight = 0
vim.g.VM_set_statusline = 0
vim.g.VM_silent_exit = 1

vim.opt.fillchars = {
    eob = " ",
    diff = "╱",
    vert = C.right_thick,
    vertleft = C.right_thick,
    vertright = C.right_thick,
    verthoriz = C.right_thick,
    horiz = C.bottom_thin,
    horizup = C.bottom_right_thin,
}

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

vim.cmd("filetype plugin indent on")
