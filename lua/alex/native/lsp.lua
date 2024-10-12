local M = {}

-- LSP config.

-- Set just below treesitter.
vim.highlight.priorities.semantic_tokens = 99

local signs = {
    text = {
        [vim.diagnostic.severity.ERROR] = "",
        [vim.diagnostic.severity.WARN] = "",
        [vim.diagnostic.severity.INFO] = "",
        [vim.diagnostic.severity.HINT] = "",
    },
    numhl = {
        [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
        [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
        [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
        [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
    },
}

-- TODO: Setup floating windows.
vim.diagnostic.config({
    signs = signs,
    virtual_text = require("alex.keymaps.utils").virtual_diagnostics,
    update_on_insert = true,
})

vim.fn.sign_define("DiagnosticSignError", { text = "", numhl = "DiagnosticSignError" })
vim.fn.sign_define("DiagnosticSignWarn", { text = "", numhl = "DiagnosticSignWarn" })
vim.fn.sign_define("DiagnosticSignInfo", { text = "", numhl = "DiagnosticSignInfo" })
vim.fn.sign_define("DiagnosticSignHint", { text = "", numhl = "DiagnosticSignHint" })

-- Diagnostics utils.

local U = require("alex.utils.chars")
local float_options = {
    border = U.border_chars_round,
    prefix = "  ",
    header = "",
}

function M.open_diagnostics_float() vim.diagnostic.open_float(float_options) end

function M.next_error()
    vim.diagnostic.goto_next({
        severity = vim.diagnostic.severity.ERROR,
        float = float_options,
    })
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
