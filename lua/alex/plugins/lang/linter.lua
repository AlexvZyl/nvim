require("lint").linters_by_ft = {
    --lua = { "luacheck" },
    python = { "flake8" },
    go = { "golangcilint" },
    -- bash = { "shellcheck" },
    -- sh = { "shellcheck" }
}

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    callback = function() require("lint").try_lint() end,
})
