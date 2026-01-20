require("nvim-autopairs").setup({})

-- Add brackets when choosing a function.
require("cmp").event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())
