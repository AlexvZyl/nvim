-- nvim --clean --headless -c "luafile tests/run.lua", with FILTER=text to run the tests with it in their name.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
require("shared.test").run(root)
