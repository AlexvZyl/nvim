-- nvim --clean --headless -c "luafile tests/bench.lua"
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
package.path = root .. "/?.lua;" .. package.path
package.preload["nvim-web-devicons"] = function()
    return {
        get_icon_by_filetype = function()
            return "i"
        end,
    }
end
require("winbar").setup({})
local winbar = require("winbar")

local path = vim.fn.tempname() .. "/dir/file.lua"
vim.fn.mkdir(vim.fs.dirname(path), "p")
vim.fn.writefile({ "a" }, path)
vim.cmd.edit(path)

local function bench(name, count, fn)
    collectgarbage()
    local start = vim.uv.hrtime()
    for _ = 1, count do
        fn()
    end
    io.stdout:write(("%-10s %8.2f us\n"):format(name, (vim.uv.hrtime() - start) / 1e3 / count))
end

bench("get", 5000, winbar.get_winbar)
bench("set", 5000, winbar.set_winbar)
-- Typing: every edit that changes whether the buffer is modified, and the redraw after.
bench("edit", 2000, function()
    vim.bo.modified = not vim.bo.modified
    vim.cmd("redraw")
end)
vim.cmd("qa!")
