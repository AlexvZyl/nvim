local U = require 'lspconfig.util'
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

LC.clangd.setup { default }
LC.nixd.setup { default }
LC.lua_ls.setup { default }
LC.julials.setup { default }
LC.bashls.setup { default }
LC.pyright.setup { default }
--LC.ruff_lsp.setup { default }
LC.rust_analyzer.setup { default }
LC.texlab.setup { default }
LC.jsonls.setup { default }
LC.yamlls.setup { default }
LC.gopls.setup { default }
--LC.hls.setup { default }
LC.terraformls.setup { default }
LC.powershell_es.setup {
    bundle_path = '~/.local/share/nvim/mason/packages/powershell-editor-services',
}

LC.eslint.setup {
    lsp_flags = lsp_flags,
    capabilities = DC,
    root_dir = U.root_pattern { '*.js', '*.ts' },
}

LC.tsserver.setup {
    lsp_flags = lsp_flags,
    capabilities = DC,
    root_dir = U.root_pattern { '*.js', '*.ts' },
}

LC.cmake.setup {
    lsp_flags = lsp_flags,
    capabilities = DC,
    root_dir = U.root_pattern 'CMakeLists.txt',
}

LC.dockerls.setup {
    lsp_flags = lsp_flags,
    capabilities = DC,
    root_dir = U.root_pattern {
        '*Dockerfile*',
        '*dockerfile*',
    },
}

LC.docker_compose_language_service.setup {
    default.lsp_flags,
    default.capabilities,
    root_dir = U.root_pattern {
        'docker-compose.yml',
        'docker-compose.yaml',
        'compose.yaml',
        'compose.yml',
    },
}

LC.html.setup {
    capabilities = DC,
    lsp_flags = lsp_flags,
    cmd = { 'html-languageserver' },
}
