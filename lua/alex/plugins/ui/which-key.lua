local U = require("alex.utils")

local border = U.border_chars_top_only_thin
local padding = { 0, 0 }

require("which-key").setup({
    delay = 750,
    win = {
        border = border,
        padding = padding,
        title = true,
    },
})

vim.cmd("set timeoutlen =1000")
