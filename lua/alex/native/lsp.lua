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

local U = require("alex.utils.chars")
local float_options = {
    border = U.border_chars_empty,
    prefix = "  ",
    header = "",
    suffix = "",
}

function M.open_diagnostics_float() vim.diagnostic.open_float(float_options) end

function M.next_error()
    vim.diagnostic.goto_next({
        severity = vim.diagnostic.severity.ERROR,
        float = float_options,
    })
    M.open_diagnostics_float()
end

function M.prev_error()
    vim.diagnostic.goto_prev({
        severity = vim.diagnostic.severity.ERROR,
        float = float_options,
    })
end

function M.next_diag() vim.diagnostic.goto_next({ float = float_options }) end

function M.prev_diag() vim.diagnostic.goto_prev({ float = float_options }) end

return M
