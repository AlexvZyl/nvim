local M = {}

local function has_statuscolumn()
    return not (vim.version.major == 0 and vim.version.minor < 9)
end

function M.no_sep()
    if not has_statuscolumn() then return end
    vim.opt.numberwidth = 4
    vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s"
end

function M.with_sep()
    if not has_statuscolumn() then return end
    vim.opt.numberwidth = 6
    vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s▎ "
end

function M.signs_right_align()
    if not has_statuscolumn() then return end
    vim.opt.numberwidth = 5
    vim.opt.statuscolumn = " %s%=%{v:relnum?v:relnum:v:lnum}%#WinSeparator#  "
end

function M.terminal()
    if not has_statuscolumn() then return end
    vim.opt_local.numberwidth = 1
    vim.opt_local.statuscolumn = " "
end


vim.opt.signcolumn = "yes"
vim.opt.relativenumber = true
vim.opt.number = true

M.default = M.signs_right_align
M.default()

return M
