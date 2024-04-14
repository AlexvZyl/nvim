local U = require 'alex.utils'

require('mason').setup {
    ui = { border = U.get_border_chars 'float' },
}

require('mason-lspconfig').setup {
    ensure_installed = {
        'rust-analyzer',
        'lua-language-server',
        'stylua',
        'luacheck',
        'julia-lsp',
        'bash-language-server',
        'pyright',
        'flake8',
        'pylint',
        'texlab',
        'cmake-language-server',
        'json-lsp',
        'shellcheck',
        'yaml-language-server',
        'clangd',
        'cpplint',
        'cpptools',
        'codelldb',
        'dockerfile-language-server',
        'docker-compose-language-service',
        'eslint-lsp',
        'typescript-language-server',
        'golangci-lint',
        'gopls',
        'haskell-language-server',
        'ruff-lsp',
        'terraform-ls',
    },
}
