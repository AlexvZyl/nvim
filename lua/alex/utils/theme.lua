local M = {}


function M.link_hl(target, link) vim.api.nvim_set_hl(0, target, { link = link }) end

function M.is_nordic() return vim.g.colors_name == 'nordic' end

function M.is_tokyonight() return vim.g.colors_name == 'tokyonight' end


return M
