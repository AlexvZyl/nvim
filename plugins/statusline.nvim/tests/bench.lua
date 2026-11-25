-- nvim --clean --headless -c "luafile tests/bench.lua", rendering with N diagnostics in the buffer, with FILTER=text
-- to run the benchmarks with it in their name. PLUGIN_ROOT runs them against the plugin there instead, like another
-- revision of it.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(os.getenv("PLUGIN_ROOT") or root)
vim.opt.rtp:prepend(root .. "/../shared.nvim")
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
-- At startup, in a new process each.
local cold = require("shared.bench").cold
cold("startup", 20, function()
    require("statusline").setup({ toggles = toggles })
end)
-- After a draw without it, so what Neovim does the first time is done.
cold("first draw", 20, vim.cmd.redraw, function()
    vim.cmd.redraw()
    require("statusline").setup({ toggles = toggles })
end)

-- Like in a config with diagnostics, which the renders run with. Loaded later, recount takes twice as long, as the
-- JIT compiles the count differently.
require("vim.diagnostic")
require("statusline").setup({ toggles = toggles })
local statusline = require("statusline")

local function bench(name, count, fn)
    require("shared.bench").run(name, count, fn, "us")
end

-- Nothing to show but the mode and the position.
bench("render empty", 5000, statusline.render)

local n = tonumber(os.getenv("N")) or 2000
local lines, diagnostics = {}, {}
for i = 1, n do
    lines[i] = "line " .. i
    diagnostics[i] = { lnum = i - 1, col = 0, message = "x", severity = i % 4 + 1 }
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.diagnostic.set(vim.api.nvim_create_namespace("bench"), 0, diagnostics)
bench("render no lsp", 5000, statusline.render)

-- Two clients, one of them efm with linters for the filetype.
vim.bo.filetype = "lua"
local clients = {
    { name = "lua_ls" },
    { name = "efm", config = { settings = { languages = { lua = { { lintSource = "luacheck" }, { lintSource = "selene" } } } } } },
}
vim.lsp.get_clients = function(_)
    return clients
end
bench("render", 5000, statusline.render)
bench("draw", 5000, function()
    vim.api.nvim_eval_statusline(vim.o.statusline, {})
end)
-- The first render after the diagnostics changed counts them again.
bench("recount", 500, function()
    require("statusline.parts").diagnostics_changed(vim.api.nvim_get_current_buf())
    statusline.render()
end)
vim.diagnostic.config({ signs = { text = { "E", "W", "I", "H" } } })
bench("render signs", 5000, statusline.render)
-- Prompts show the clients of the buffer before them.
vim.bo.filetype = "TelescopePrompt"
bench("render prompt", 5000, statusline.render)
vim.bo.filetype = "lua"
require("statusline.config").options.toggles = vim.list_extend(vim.deepcopy(toggles), vim.deepcopy(toggles))
bench("render toggles", 5000, statusline.render)
require("shared.bench").finish()
