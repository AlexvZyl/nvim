local L = require("lint")

local cpp_check_args = require("lint").linters.cppcheck.args
table.insert(cpp_check_args, "--suppress=missingIncludeSystem")
table.insert(cpp_check_args, "--suppress=missingInclude")

L.linters_by_ft = {
    -- lua = { "luacheck" },
    python = { "flake8" },
    go = { "golangcilint" },
    -- cpp = { "cppcheck" },
    bash = { "shellcheck" },
    sh = { "shellcheck" },
    proto = { "buf_lint" },
}

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    callback = function()
        require("lint").try_lint()
    end,
})
