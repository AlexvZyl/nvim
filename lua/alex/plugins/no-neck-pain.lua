local M = {}

M.enabled = false

function M.setup()
    require("no-neck-pain").setup({
        width = 140,
        autocmds = {
            skipEnteringNoNeckPainBuffer = true,
        }
    })
end

function M.toggle()
    M.enabled = not M.enabled
    vim.cmd("NoNeckPain")
    require("alex.plugins.lualine").refresh_statusline()
end

function M.enable()
    if not M.enabled then
        M.toggle()
    end
end

function M.disable()
    if M.enabled then
        M.toggle()
    end
end

return M
