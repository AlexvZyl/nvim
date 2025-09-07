local M = {}

M.enabled = false

function M.setup()
    require("no-neck-pain").setup({
        width = 140,
    })
end

function M.toggle()
    M.enabled = not M.enabled
    vim.cmd("NoNeckPain")
    require("alex.plugins.lualine").refresh_statusline()
end

return M
