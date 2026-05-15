local M = {}

function M.relative()
    vim.o.relativenumber = true
    vim.opt.statuscolumn = " %s%=%{v:relnum?v:relnum:v:lnum}%#WinSeparator#  "
end

function M.absolute()
    vim.o.relativenumber = false
    vim.opt.statuscolumn = " %s%=%{v:lnum}%#WinSeparator#  "
end

function M.terminal()
    vim.opt_local.numberwidth = 1
    vim.opt_local.statuscolumn = " "
end

function M.toggle_relative()
    if vim.o.relativenumber then
        M.absolute()
    else
        M.relative()
    end
end

vim.opt.signcolumn = "yes"
vim.opt.number = true
vim.opt.numberwidth = 4

M.relative()

return M
