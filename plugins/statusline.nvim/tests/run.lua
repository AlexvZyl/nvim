-- nvim --clean --headless -c "luafile tests/run.lua", with FILTER=text to run the tests with it in their name.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/../shared.nvim")
package.path = root .. "/?.lua;" .. package.path
vim.o.report, vim.o.showmode = 10000, false
require("statusline").setup({
    toggles = {
        {
            enabled = function()
                return true
            end,
            icon = "on",
        },
        {
            enabled = function()
                return false
            end,
            icon = "off",
        },
    },
})

require("shared.test").run(root)
