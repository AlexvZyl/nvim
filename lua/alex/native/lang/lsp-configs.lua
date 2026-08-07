local LU = require("lspconfig.util")

vim.lsp.commands = vim.lsp.commands or {}
vim.lsp.commands["editor.action.triggerParameterHints"] = function()
    vim.lsp.buf.signature_help()
end

vim.lsp.config("*", {
    capabilities = {
        textDocument = {
            completion = {
                completionItem = {
                    snippetSupport = true,
                },
            },
        },
    },
})

-- These LSPs use the configs provided by `nvim-lspconfig`.

vim.lsp.enable("cssls")
vim.lsp.enable("nixd")
vim.lsp.enable("bashls")
vim.lsp.enable("pyright")
vim.lsp.enable("rust_analyzer")
vim.lsp.enable("yamlls")
vim.lsp.enable("gopls")
vim.lsp.enable("terraformls")
vim.lsp.enable("buf_ls")
vim.lsp.enable("clangd")
vim.lsp.enable("ts_ls")
vim.lsp.enable("cmake")
vim.lsp.enable("dockerls")
vim.lsp.enable("docker_language_server")
vim.lsp.enable("html")
vim.lsp.enable("jsonls")
vim.lsp.enable("lua_ls")
vim.lsp.enable("docker_compose_language_service")
vim.lsp.enable("zls")
vim.lsp.enable("kotlin_lsp")
vim.lsp.enable("efm")

-- Override some of the configs.

vim.lsp.config("cmake", {
    root_dir = LU.root_pattern("CMakeLists.txt"),
})

vim.lsp.config("docker_compose_language_service", {
    root_dir = LU.root_pattern({
        "docker-compose.ya?ml",
        "compose.ya?ml",
    }),
})

vim.lsp.config("bashls", {
    settings = {
        bashIde = {
            shellcheckArguments = { "-x" },
        },
    },
})

vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            completion = {
                callSnippet = "Replace",
            },
        },
    },
})

vim.lsp.config("kotlin_lsp", {
    cmd = { vim.fn.expand("$HOME/.local/opt/kotlin-lsp/bin/intellij-server"), "--stdio" },
    root_markers = { ".git" },
})

vim.lsp.config("efm", {
    cmd = { "efm-langserver", "-loglevel", "1" },
    filetypes = { "kotlin", "rust" },
    init_options = { documentFormatting = true, documentRangeFormatting = true },
    settings = {
        rootMarkers = { ".git/" },
        lintDebounce = "500ms",
        languages = {
            kotlin = {
                -- {
                --     formatCommand = "ktlint --format --stdin --log-level=none",
                --     formatStdin = true,
                -- },
                -- {
                --     lintCommand = "ktlint --reporter=plain --stdin",
                --     lintStdin = true,
                --     lintFormats = { "%f:%l:%c: %m" },
                --     lintSource = "ktlint",
                --     lintAfterOpen = true,
                -- },
                {
                    lintCommand = "detekt --input ${INPUT}",
                    lintStdin = false,
                    lintFormats = { "%f:%l:%c: %t%*[^:]: %m" },
                    lintSource = "detekt",
                    lintAfterOpen = true,
                    rootMarkers = { "detekt.yml", ".git/" },
                },
            },
            rust = {
                {
                    lintCommand = "cargo clippy --message-format=short --quiet",
                    lintStdin = false,
                    lintFormats = { "%f:%l:%c: %t%*[^:]: %m" },
                    lintSource = "clippy",
                    lintAfterOpen = true,
                    rootMarkers = { "Cargo.toml", ".git/" },
                },
            },
        },
    },
})
