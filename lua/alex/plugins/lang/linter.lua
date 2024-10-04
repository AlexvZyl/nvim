local L = require("lint")

L.linters_by_ft = {
    --lua = { "luacheck" },
    python = { "flake8" },
    go = { "golangcilint" },
    cpp = { "cppcheck" },
    -- bash = { "shellcheck" },
    -- sh = { "shellcheck" }
}

L.linters.cppcheck.args = { "--suppress=missingIncludeSystem" }

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    callback = function() require("lint").try_lint() end,
})
