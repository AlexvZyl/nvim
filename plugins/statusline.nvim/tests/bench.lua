-- nvim --clean --headless -c "luafile tests/bench.lua", rendering with N diagnostics in the buffer.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
package.path = root .. "/?.lua;" .. package.path
local toggles = {}
for i = 1, 4 do
    toggles[i] = {
        enabled = function()
            return i % 2 == 0
        end,
        icon = "t" .. i,
    }
end
require("statusline").setup({ toggles = toggles })
local statusline = require("statusline")

local n = tonumber(os.getenv("N")) or 2000
local lines, diagnostics = {}, {}
for i = 1, n do
    lines[i] = "line " .. i
    diagnostics[i] = { lnum = i - 1, col = 0, message = "x", severity = i % 4 + 1 }
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.diagnostic.set(vim.api.nvim_create_namespace("bench"), 0, diagnostics)
-- Two clients, one of them efm with linters for the filetype.
vim.bo.filetype = "lua"
local clients = {
    { name = "lua_ls" },
    { name = "efm", config = { settings = { languages = { lua = { { lintSource = "luacheck" }, { lintSource = "selene" } } } } } },
}
vim.lsp.get_clients = function(_)
    return clients
end

local function bench(name, count, fn)
    collectgarbage()
    local start = vim.uv.hrtime()
    for _ = 1, count do
        fn()
    end
    io.stdout:write(("%-10s %8.2f us\n"):format(name, (vim.uv.hrtime() - start) / 1e3 / count))
end

bench("render", 5000, statusline.render)
bench("draw", 5000, function()
    vim.api.nvim_eval_statusline(vim.o.statusline, {})
end)
vim.cmd("qa!")
