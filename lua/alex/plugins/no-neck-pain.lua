local M = {}

M.enabled = false

function M.setup()
    require("no-neck-pain").setup({
        width = 140,
        autocmds = {
            skipEnteringNoNeckPainBuffer = true,
        }
    })

    vim.api.nvim_create_autocmd("FileType", {
        once = true,
        callback = function(_)
            M.enable()
        end,
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
