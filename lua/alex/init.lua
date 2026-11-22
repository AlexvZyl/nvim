-- Order is important.

if not require("alex.environments").should_setup then
    return
end

-- Needed before lazy, the plugin conds depend on it.
vim.opt.rtp:prepend(vim.fn.stdpath("config") .. "/plugins/review.nvim")
require("review").setup()
require("alex.cwd")
require("alex.options")
require("alex.lazy")
require("alex.native")
require("alex.keymaps")
