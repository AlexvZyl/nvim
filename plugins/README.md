# Plugins

Plugins I maintain myself.  Each directory is a self-contained plugin root.

## Installation

Lazy clones this whole repo, but only the plugin directories get added to the runtimepath.  Keep `lazy = true`, otherwise the rest of my config gets loaded too.

```lua
{
    "AlexvZyl/nvim",
    name = "alex-plugins",
    lazy = true,
    priority = 1000,
    init = function(plugin)
        vim.opt.rtp:prepend(plugin.dir .. "/plugins/default.nvim")
        vim.opt.rtp:prepend(plugin.dir .. "/plugins/review.nvim")
        require("default").load()
        require("review").setup()
    end,
},
```

## Plugins

- [default.nvim](default.nvim): The default neovim theme, but with some minor improvements.
- [review.nvim](review.nvim): Review the diff of the current branch against a base ref.
