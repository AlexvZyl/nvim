local U = require("alex.utils")

require("which-key").setup({
    window = {
        border = U.border_chars_top_only,
        margin = { 0, 0, 1, 0 },
        padding = { 0, 0, 0, 0 },
    },
})
vim.cmd("set timeoutlen =1000")
