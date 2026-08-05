require("tree-sitter-manager").setup({
    ensure_installed = {
        "rust",
        "kotlin",
        "lua",
        "bash",
        "zsh",
        "python",
        "cpp",
        "toml",
        "xml",
        "yaml",
        "dockerfile",
        "typescript",
        "json"
    },
})
