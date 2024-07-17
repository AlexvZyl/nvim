local U = require("alex.utils")

require("which-key").setup({
    win = {
        border = U.border_chars_top_only,
        padding = { 0, 0, 0, 0 },
    },
})
vim.cmd("set timeoutlen =1000")
