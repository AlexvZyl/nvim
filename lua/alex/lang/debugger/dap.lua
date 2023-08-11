local dap = require 'dap'

dap.adapters.cppdbg = {
    id = 'cppdbg',
    type = 'executable',
    command = '/home/alex/.config/nvim/lua/alex/lang/debugger/tools/vscode-cpptools/extension/debugAdapters/bin/OpenDebugAD7',
}

local cache = require 'alex.lang.debugger.cache'

-- C++
dap.adapters.codelldb = {
    command = vim.fn.stdpath 'data' .. '/mason/bin/codelldb --port 13000',
    type = 'server',
    host = '127.0.0.1',
    port = 13000,
}
dap.configurations.cpp = {
    {
        name = 'Executable',
        type = 'codelldb', -- Technically only for Mac I think?
        request = 'launch',
        program = function()
            local path = cache.check_exe_cache(vim.fn.getcwd())
            local input = vim.fn.input('Debug: ', path, 'file')
            cache.update_exe_cache(vim.fn.getcwd(), input)
            return input
        end,
        cwd = '${workspaceFolder}',
        stopAtEntry = true,
    },
}

dap.configurations.c = dap.configurations.cpp
dap.configurations.rust = dap.configurations.cpp
