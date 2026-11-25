-- nvim --clean --headless -c "luafile tests/run.lua", with FILTER=text to run the tests with it in their name.
-- Not -l, which does not resize the window to the size the tests set.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/../shared.nvim")
package.path = root .. "/?.lua;" .. package.path
vim.o.showmode = false
-- Messages would print in the middle of the results, like "5 fewer lines".
vim.o.report = 10000
vim.notify = function(message)
    io.stdout:write("      " .. message .. "\n")
end
require("review").setup({})

require("shared.test").run(root)
