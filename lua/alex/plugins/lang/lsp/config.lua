local DC = require("cmp_nvim_lsp").default_capabilities()

local M = {}

M.lsp_flags = {
    debounce_text_changes = 100, -- ms
}

M.default = {
    lsp_flags = M.lsp_flags,
    capabilities = DC,
}

M.capabilities = DC

return M
