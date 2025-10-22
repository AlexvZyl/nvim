local L = require("lint")

-- local cpp_check = L.linters.cppcheck
-- table.insert(cpp_check.args, "--enable=information,warning")
-- table.insert(cpp_check.args, "--disable=warning")
-- local lua_check = L.linters.luacheck
-- table.insert(lua_check.args, 1, "--enable=information,warning")

local shellcheck = L.linters.shellcheck
table.insert(shellcheck.args, "-x")

L.linters_by_ft = {
    -- lua = { "luacheck" },
    python = { "flake8" },
    go = { "golangcilint" },
    cpp = { "cppcheck" },
    bash = { "shellcheck" },
    sh = { "shellcheck" },
    proto = { "buf_lint" },
}

vim.api.nvim_create_autocmd({ "BufWritePost", "BufWinEnter" }, {
    callback = function()
        require("lint").try_lint()
    end,
})
