local U = require 'alex.utils'

require('mason').setup {
    ui = { border = U.get_border_chars 'float' },
}

local registry = require 'mason-registry'

local packages = {
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
}

registry.refresh(function()
    for _, pkg_name in ipairs(packages) do
        local pkg = registry.get_package(pkg_name)
        if not pkg:is_installed() then pkg:install() end
    end
end)
