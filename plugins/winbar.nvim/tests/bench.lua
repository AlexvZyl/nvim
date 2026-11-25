-- nvim --clean --headless -c "luafile tests/bench.lua", with FILTER=text to run the benchmarks with it in their name.
-- PLUGIN_ROOT runs them against the plugin there instead, like another revision of it.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(os.getenv("PLUGIN_ROOT") or root)
vim.opt.rtp:prepend(root .. "/../shared.nvim")
package.path = root .. "/?.lua;" .. package.path
package.preload["nvim-web-devicons"] = function()
    return {
        get_icon_by_filetype = function()
            return "i"
        end,
    }
end
require("winbar").setup({ exclude = { "excluded" } })
local winbar = require("winbar")

local function bench(name, count, fn)
    require("shared.bench").run(name, count, fn, "us")
end

local function edit(name)
    local path = vim.fn.tempname() .. "/dir/" .. name
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile({ "a" }, path)
    vim.cmd.edit(path)
end

edit("file.lua")
bench("get", 5000, winbar.get_winbar)
bench("set", 5000, winbar.set_winbar)
-- Typing: every edit that changes whether the buffer is modified, and the redraw after.
bench("edit", 2000, function()
    vim.bo.modified = not vim.bo.modified
    vim.cmd("redraw")
end)
-- Moving between windows sets the bar of each window entered.
vim.cmd("vsplit | split | vsplit")
bench("switch", 2000, function()
    vim.cmd("wincmd w")
end)
vim.cmd("only")
vim.bo.readonly = true
bench("get readonly", 5000, winbar.get_winbar)

vim.cmd.enew()
bench("get unnamed", 5000, winbar.get_winbar)
vim.bo.filetype = "help"
bench("get help", 5000, winbar.get_winbar)
vim.bo.filetype = "checkhealth"
bench("get bar", 5000, winbar.get_winbar)
vim.bo.filetype = "oil"
vim.api.nvim_buf_set_name(0, "oil:///tmp/dir/")
bench("get oil", 5000, winbar.get_winbar)
vim.bo.filetype = "excluded"
bench("set excluded", 5000, winbar.set_winbar)

vim.cmd.enew()
vim.cmd.terminal()
bench("get terminal", 5000, winbar.get_winbar)

vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, { relative = "editor", row = 1, col = 1, width = 20, height = 5 })
bench("set float", 5000, winbar.set_winbar)
require("shared.bench").finish()
