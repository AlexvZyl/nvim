local M = {}

M.enabled = false

function M.setup()
    require("no-neck-pain").setup({
        width = 140,
        autocmds = {
            skipEnteringNoNeckPainBuffer = true,
        }
    })

    -- This means we did not start with a dashboard.
    -- Enable no-neck-pain.
    if vim.bo.filetype ~= "dashboard" then
        M.enable()
    else
        -- Started with dashboard, setup event for starting no-neck-pain.
        vim.api.nvim_create_autocmd("BufReadPost", {
            once = true,
            callback = function()
                M.enable()
            end,
        })
    end
end

function M.toggle()
    M.enabled = not M.enabled
    vim.cmd.NoNeckPain()
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
