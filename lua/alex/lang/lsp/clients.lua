-- Run install-servers.sh to install all the servers used below.

local U = require 'lspconfig/util'
local lsp_config = require 'lspconfig'
local capabilities = require('cmp_nvim_lsp').default_capabilities()

local lsp_flags = {
    -- Prevent the LSP client from making too many calls.
    debounce_text_changes = 250, -- ms
}

local default = {
    lsp_flags = lsp_flags,
    capabilities = capabilities,
}

-- Setup LSPs.
lsp_config.clangd.setup { default }
lsp_config.lua_ls.setup { default }
lsp_config.julials.setup { default }
lsp_config.bashls.setup { default }
lsp_config.pyright.setup { default }
lsp_config.rust_analyzer.setup { default }
lsp_config.texlab.setup { default }
lsp_config.cmake.setup {
    lsp_flags = lsp_flags,
    capabilities = capabilities,
    root_dir = U.root_pattern 'CMakeLists.txt',
}
lsp_config.jsonls.setup { default }
lsp_config.yamlls.setup { default }
