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

| Command | Function | Does |
|---|---|---|
| | `require("statusline").setup(opts)` | Sets the statusline. |
| | `require("statusline").render()` | The statusline string. |
| | `require("statusline").refresh()` | Redraws the statusline. |
