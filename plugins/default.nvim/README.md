# default.nvim

The default Neovim theme, slightly improved.

## Setup

```lua
require("default").load({
    overrides = {
        Comment = { fg = require("default.palette").green, italic = true },
    },
})
```

## Commands

| Command | Function | Does |
|---|---|---|
| `:colorscheme default` | `require("default").load(opts)` | Loads the theme. |
