local M = {}

-- Signs

vim.fn.sign_define(
    "DiagnosticSignError",
    { text = "", texthl = "", linehl = "", numhl = "DiagnosticSignError" }
)
vim.fn.sign_define(
    "DiagnosticSignWarn",
    { text = "", texthl = "", linehl = "", numhl = "DiagnosticSignWarn" }
)
vim.fn.sign_define(
    "DiagnosticSignInfo",
    { text = "", texthl = "", linehl = "", numhl = "DiagnosticSignInfo" }
)
vim.fn.sign_define(
    "DiagnosticSignHint",
    { text = "󱤅", texthl = "", linehl = "", numhl = "DiagnosticSignHint" }
)

-- LSP config.

local config = {
    virtual_text = false,
    signs = true,
    update_on_insert = true,
}
vim.diagnostic.config(config)

-- Diagnostics utils.

local float_options = {}

function M.open_diagnostics_float() vim.diagnostic.open_float(float_options) end

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

function M.next_diag() vim.diagnostic.goto_next() end

function M.prev_diag() vim.diagnostic.goto_prev() end

return M
