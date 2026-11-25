-- nvim --clean --headless -c "luafile tests/bench.lua", with FILTER=text to run the benchmarks with it in their name.
-- PLUGIN_ROOT runs them against the plugin there instead, like another revision of it.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(os.getenv("PLUGIN_ROOT") or root)
vim.opt.rtp:prepend(root .. "/../shared.nvim")
local bench = require("shared.bench")

-- At startup, in a new process each.
bench.cold("startup", 20, function()
    require("default").load()
end)
bench.cold("colorscheme", 20, function()
    vim.cmd.colorscheme("default")
end)

require("default").load()
-- Loading it again after another colorscheme.
bench.run("load", 500, function()
    vim.g.colors_name = "other"
    require("default").load()
end, "us")
bench.finish()
