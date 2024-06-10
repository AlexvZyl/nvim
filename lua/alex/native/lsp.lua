local M = {}

vim.cmd([[
    sign define DiagnosticSignError text= texthl= linehl= numhl=DiagnosticSignError
    sign define DiagnosticSignWarn  text= texthl= linehl= numhl=DiagnosticSignWarn
    sign define DiagnosticSignInfo  text= texthl= linehl= numhl=DiagnosticSignInfo
    sign define DiagnosticSignHint  text=󱤅 texthl= linehl= numhl=DiagnosticSignHint
]])

local config = {
    virtual_text = false,
    signs = true,
    update_on_insert = true,
}
vim.diagnostic.config(config)

function M.open_diagnostics_float() vim.diagnostic.open_float() end

function M.next_error()
    vim.diagnostic.goto_next({
        severity = vim.diagnostic.severity.ERROR,
    })
end

function M.prev_error()
    vim.diagnostic.goto_prev({
        severity = vim.diagnostic.severity.ERROR,
    })
end

function M.next_diag()
    vim.diagnostic.goto_next()
end

function M.prev_diag()
    vim.diagnostic.goto_prev()
end

return M
