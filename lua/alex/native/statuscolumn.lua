local M = {}

vim.opt.signcolumn = "yes"

function M.no_sep()
    vim.opt.numberwidth = 4
    vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s"
end

function M.with_sep()
    vim.opt.numberwidth = 6
    vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s▎ "
end

-- Signs first, right aligned relative number
function M.signs_right_align()
    vim.opt.numberwidth = 5
    vim.opt.statuscolumn = " %s%=%{v:relnum?v:relnum:v:lnum}%#WinSeparator#  "
end

function M.terminal()
    vim.opt_local.numberwidth = 1
    vim.opt_local.statuscolumn = " "
end

-- Statuscolumn was added in 0.9.
if vim.version.major == 0 and vim.version.minor < 9 then
    -- Fallback for when cannot set custom statuscolumn.
    vim.opt.relativenumber = true
    vim.opt.number = true
    vim.opt.signcolumn = "yes"
else
    M.signs_right_align()
end

return M
