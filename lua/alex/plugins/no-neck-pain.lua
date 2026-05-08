local M = {}

M.enabled = false

function M.setup()
    require("no-neck-pain").setup({
        width = 140,
        autocmds = {
            skipEnteringNoNeckPainBuffer = true,
        },
    })

    M.enable()
end

function M.toggle()
    M.enabled = not M.enabled
    vim.cmd.NoNeckPain()
    require("alex.native.statusline").refresh()
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
