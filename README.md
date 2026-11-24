# "${HOME}/.config/nvim"

[![review.nvim](https://github.com/AlexvZyl/nvim/actions/workflows/review.yml/badge.svg)](https://github.com/AlexvZyl/nvim/actions/workflows/review.yml)

<img width="2559" height="1439" alt="image" src="https://github.com/user-attachments/assets/9df1727d-fbc1-4987-93db-0f0e8f55c228" />

Configuration files and custom modules for Neovim.

I do not use a distro becuase:
1. They are fragile.
2. I like doing things myself.

## Some notes

- I am on an endeavour to reduce the surface of `lua/alex/plugins` as much as possible, and replace it with custom stuff in `lua/alex/native` (within reason, of course).
- I am not setting up my packages in the way that is described by `lazy.nvim`.  I am trying to keep my configs "package manager agnostic" as far as possible.
- I try to keep all of the key bindings in [one file](https://github.com/AlexvZyl/nvim/blob/main/lua/alex/keymaps.lua) so that it is easier to keep track of everything and prevent conflicts.
- You can add more LSPs to the end of [this file](https://github.com/AlexvZyl/nvim/blob/main/lua/alex/native/lang/lsp-configs.lua).

## Plugins

I keep my own plugins in [plugins](plugins).

| Plugin | Description |
|---|---|
| [default.nvim](https://github.com/AlexvZyl/nvim/tree/main/plugins/default.nvim) | The default Neovim theme, slightly improved. |
| [review.nvim](https://github.com/AlexvZyl/nvim/tree/main/plugins/review.nvim) | Review a branch against a base ref, in place. |

To load them with lazy:

```lua
{
    "AlexvZyl/nvim",
    lazy = true, -- Prevent my entire config from loading.
    priority = 1000,
    dependencies = { "nvim-tree/nvim-web-devicons", "nvim-telescope/telescope.nvim" },
    init = function(plugin)
        vim.opt.rtp:prepend(plugin.dir .. "/plugins/default.nvim")
        vim.opt.rtp:prepend(plugin.dir .. "/plugins/review.nvim")
        require("default").load()
        require("review").setup()
    end,
},
```
