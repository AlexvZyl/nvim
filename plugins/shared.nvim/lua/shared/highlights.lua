local M = {}

-- Groups linked to others, or set to attributes when given a table, as defaults so colorschemes can override them.
function M.link(groups)
    for group, link in pairs(groups) do
        local hl = type(link) == "table" and link or { link = link }
        vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", hl, { default = true }))
    end
end

return M
