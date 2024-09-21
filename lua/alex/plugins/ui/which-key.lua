local U = require("alex.utils")

local border = U.border_chars_top_only_thin
local padding = { 0, 0 }
if U.is_default() then
    border = U.border_chars_top_only_normal
end

require("which-key").setup({
    win = {
        border = border,
        padding = padding,
        title = false
    },
})

vim.cmd("set timeoutlen =1000")
