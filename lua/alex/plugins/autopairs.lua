-- Only enable autopairs for completion, not for manual typing
require("cmp").event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())
