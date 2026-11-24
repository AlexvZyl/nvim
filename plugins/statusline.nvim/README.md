# statusline.nvim

A minimal global statusline.

## Setup

```lua
require("statusline").setup({
    toggles = {
        {
            enabled = function()
                return vim.o.relativenumber
            end,
            icon = " ",
        },
    },
})
```

## Commands

| Function | Does |
|---|---|
| `require("statusline").refresh()` | Redraws the statusline. |
