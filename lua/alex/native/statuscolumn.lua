local M = {}

M.relative = true

function M.default()
    vim.opt.numberwidth = 5
    vim.o.relativenumber = M.relative
    vim.opt.statuscolumn = " %s%=%{v:relnum?v:relnum:v:lnum}%#WinSeparator#  "
end

function M.terminal()
    vim.opt_local.numberwidth = 1
    vim.opt_local.statuscolumn = " "
end

function M.refresh()
    vim.cmd("redraw!")
end

function M.toggle_relative()
    M.relative = not M.relative
    M.default()
    M.refresh()
end

vim.opt.signcolumn = "yes"
vim.opt.number = true

M.default()

return M
