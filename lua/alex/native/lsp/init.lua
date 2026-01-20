require("alex.native.lsp.defaults")
require("alex.native.lsp.tsn")

local M = {}

local U = require("alex.utils")

-- Enable logging.
vim.lsp.log.set_level("error")

-- This command got removed from lsp-config.  Re-add.
vim.api.nvim_create_user_command("LspLog", function()
    vim.cmd.edit(vim.lsp.log.get_filename())
end, {})

-- Place this just below treesitter.
-- I like treesitter highlights more than the LSP ones.
vim.hl.priorities.semantic_tokens = 99

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

M.virtual_diagnostics = false
function M.toggle_virtual_diagnostics()
    M.virtual_diagnostics = not M.virtual_diagnostics
    vim.diagnostic.config({
        signs = signs,
        virtual_lines = M.virtual_diagnostics,
        virtual_text = false,
        update_in_insert = true,
        severity_sort = true,
    })
    U.merge_highlights_table({
        DiagnosticUnderlineError = { undercurl = not M.virtual_diagnostics },
        DiagnosticUnderlineWarn = { undercurl = not M.virtual_diagnostics },
    })
    require("alex.plugins.lualine").refresh_statusline()
end

-- Setup diags.
vim.diagnostic.config({
    signs = signs,
    virtual_lines = M.virtual_diagnostics,
    virtual_text = false,
    update_in_insert = true,
    severity_sort = true,
})
U.merge_highlights_table({
    DiagnosticUnderlineError = { undercurl = not M.virtual_diagnostics, underline = false },
    DiagnosticUnderlineWarn = { undercurl = not M.virtual_diagnostics, underline = false },
    DiagnosticUnderlineHint = { undercurl = false, underline = false },
    DiagnosticUnderlineOk = { undercurl = false, underline = false },
    DiagnosticUnderlineInfo = { undercurl = false, underline = false },
})

-- TODO: For some reason this is still required for telescope stuff.
vim.fn.sign_define("DiagnosticSignError", { text = "", numhl = "DiagnosticSignError" })
vim.fn.sign_define("DiagnosticSignWarn", { text = "", numhl = "DiagnosticSignWarn" })
vim.fn.sign_define("DiagnosticSignInfo", { text = "", numhl = "DiagnosticSignInfo" })
vim.fn.sign_define("DiagnosticSignHint", { text = "", numhl = "DiagnosticSignHint" })

local float_options = {
    border = U.border_chars_round,
    prefix = "  ",
    header = "",
    severity_sort = true,
}

function M.open_diagnostics_float()
    vim.diagnostic.open_float(float_options)
end

function M.next_error()
    vim.diagnostic.jump({
        count = 1,
        severity = vim.diagnostic.severity.ERROR,
        float = float_options,
    })
end

function M.prev_error()
    vim.diagnostic.jump({
        count = -1,
        severity = vim.diagnostic.severity.ERROR,
        float = float_options,
    })
end

function M.next_diag()
    vim.diagnostic.jump({
        count = 1,
        float = float_options,
    })
end

function M.prev_diag()
    vim.diagnostic.jump({
        count = -1,
        float = float_options,
    })
end

function M.remove_trailing_whitespace()
    local cursor_position = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_exec([[%s/\s\+$//e]], false)
    vim.cmd("noh")
    vim.api.nvim_win_set_cursor(0, cursor_position)
end

function M.format_via_lsp()
    local status, _ = pcall(vim.lsp.buf.format)
    if not status then
        vim.notify("Format failed")
    end
end

function M.format_buffer()
    M.remove_trailing_whitespace()
    M.format_via_lsp()
end

M.format_enabled = false
function M.toggle_format_enabled()
    M.format_enabled = not M.format_enabled
    require("alex.plugins.lualine").refresh_statusline()
end

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    callback = function()
        local L = require("alex.native.lsp")
        if L.format_enabled then
            L.format_buffer()
        end
    end,
})

return M
