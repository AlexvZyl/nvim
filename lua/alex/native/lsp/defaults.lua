local LU = require("lspconfig.util")

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
vim.lsp.enable("zls")
vim.lsp.enable("clangd")
vim.lsp.enable("ts_ls")
vim.lsp.enable("cmake")
vim.lsp.enable("dockerls")
vim.lsp.enable("docker_compose_language_service")
vim.lsp.enable("html")
vim.lsp.enable("jsonls")
vim.lsp.enable("zls")
vim.lsp.enable("lua_ls")

-- Override some of the configs.

vim.lsp.config("clangd", {
    filetypes = { "c", "cpp", "objc", "objcpp" },
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

vim.lsp.config("ts_ls", {
    root_dir = LU.root_pattern({ "*.js", "*.ts" }),
})

vim.lsp.config("cmake", {
    root_dir = LU.root_pattern("CMakeLists.txt"),
})

vim.lsp.config("dockerls", {
    root_dir = LU.root_pattern({
        "[dD]ockerfile*",
    }),
})

vim.lsp.config("docker_compose_language_service", {
    root_dir = LU.root_pattern({
        "docker-compose.ya?ml",
        "compose.ya?ml",
    }),
})
