local LU = require("lspconfig.util")
local LC = require("lspconfig")
local C = require("alex.plugins.lang.lsp.config")

require("lspconfig.ui.windows").default_options.border =
    require("alex.utils").get_border_chars("float")

-- Setup LSPs.

LC.clangd.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    root_dir = LU.root_pattern(
        ".clangd",
        ".clang-tidy",
        ".clang-format",
        "compile_commands.json",
        "compile_flags.txt",
        "configure.ac",
        ".git"
    ),
})

LC.cssls.setup({ C.default })
LC.nixd.setup({ C.default })
LC.lua_ls.setup({ C.default })
LC.julials.setup({ C.default })
LC.bashls.setup({ C.default })
LC.pyright.setup({ C.default })
--LC.ruff_lsp.setup { C.default }
LC.rust_analyzer.setup({ C.default })
LC.texlab.setup({ C.default })
LC.yamlls.setup({ C.default })
LC.gopls.setup({ C.default })
--LC.hls.setup { C.default }
LC.terraformls.setup({ C.default })

LC.eslint.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    root_dir = LU.root_pattern({ "*.js", "*.ts" }),
})

LC.ts_ls.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    root_dir = LU.root_pattern({ "*.js", "*.ts" }),
})

LC.cmake.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    root_dir = LU.root_pattern("CMakeLists.txt"),
})

LC.dockerls.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    root_dir = LU.root_pattern({
        "[dD]ockerfile*",
    }),
})

LC.docker_compose_language_service.setup({
    C.default.lsp_flags,
    C.default.capabilities,
    root_dir = LU.root_pattern({
        "docker-compose.ya?ml",
        "compose.ya?ml",
    }),
})

LC.html.setup({
    capabilities = C.capabilities,
    lsp_flags = C.lsp_flags,
    cmd = { "html-languageserver" },
})

LC.jsonls.setup({
    capabilities = C.capabilities,
    lsp_flags = C.lsp_flags,
    cmd = { "json-languageserver", "--stdio" },
})

-- Extensions.
require("alex.plugins.lang.lsp.tsn")
