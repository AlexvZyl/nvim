# default.nvim

The default neovim theme, but with some minor improvements.

## Installation

Lazy:
```lua
{
    'AlexvZyl/default.nvim',
    lazy = false,
    priority = 1000,
    config = function()
        require('default').load()
    end
}
```

## Config

The config is minimal for a reason, I don't want to maintain a lot of code.  If you want more than this I recommend you fork the repo.

```lua
local palette = require('default.palette')

require('default').load({
    overrides = {
        Comment = {
            fg = palette.green,
            bg = "#000000",
            sp = "#ff0000",
            bold = true,
            italic = true,
            underline = true,
            undercurl = true,
        },
    }
})
```

Lualine:
```lua
require("lualine").setup({
    options = { theme = "default" }
})

```

## Screenshots

<p>
  <img width="49%" alt="image" src="https://github.com/user-attachments/assets/174dd043-ed1f-437b-9a13-5e23e1ab29fd" />
  <img width="49%" alt="image" src="https://github.com/user-attachments/assets/5079c85d-b82d-4cb6-9619-80043707ecee" />
</p>

<p>
  <img width="49%" alt="image" src="https://github.com/user-attachments/assets/c91d3d3f-fca2-4d31-986b-94a7d8c0fa3f" />
  <img width="49%" alt="image" src="https://github.com/user-attachments/assets/0515daf1-7ae9-4cca-93e9-a3c182ccd5ad" />
</p>
