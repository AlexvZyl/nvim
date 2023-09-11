-- Statuscolumn was added in 0.9.
if vim.version.major == 0 and vim.version.minor < 9 then return end

 --No separator.
--vim.opt.numberwidth = 4
--vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s"

-- With sepaartor.
 --vim.opt.numberwidth = 6
 --vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%=%s▎ "
 --vim.opt.statuscolumn = "%= %{v:virtnum < 1 ? (v:relnum ? v:relnum : v:lnum) : ''}%= %s "

-- First diag signs?
vim.opt.numberwidth = 7
vim.opt.statuscolumn = " %s%=%{v:relnum?v:relnum:v:lnum}   "

--alksdhjikf
