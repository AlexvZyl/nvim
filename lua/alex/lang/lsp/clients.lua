-- Run install-servers.sh to install all the servers used below.

local U = require 'lspconfig/util'
local LC = require 'lspconfig'
local DC = require('cmp_nvim_lsp').default_capabilities()

local lsp_flags = {
    -- Prevent the LSP client from making too many calls.
    debounce_text_changes = 250, -- ms
}

local default = {
    lsp_flags = lsp_flags,
    capabilities = DC,
}

-- Setup LSPs.
--lsp_config.clangd.setup { default }
LC.ccls.setup { default }
LC.lua_ls.setup { default }
LC.julials.setup { default }
LC.bashls.setup { default }
LC.pyright.setup { default }
LC.rust_analyzer.setup { default }
LC.texlab.setup { default }
LC.jsonls.setup { default }
LC.yamlls.setup { default }

LC.cmake.setup {
    lsp_flags = lsp_flags,
    capabilities = DC,
    root_dir = U.root_pattern 'CMakeLists.txt',
}

LC.dockerls.setup {
    lsp_flags = lsp_flags,
    capabilities = DC,
    root_dir = U.root_pattern {
        'Dockerfile',
        'dockerfile',
    },
}

LC.docker_compose_language_service.setup {
    default.lsp_flags,
    default.capabilities,
    root_dir = U.root_pattern {
        'docker-compose.yml',
        'docker-compose.yml',
        'compose.yaml',
        'compose.yml',
    },
}
