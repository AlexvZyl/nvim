# statusline.nvim

A global statusline with the mode, LSP clients, diagnostics, toggles and the cursor position.

## Setup

```lua
require("statusline").setup({
    -- Shown on the right, highlighted by whether they are enabled.
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

## Functions

| Function | Does |
|---|---|
| `require("statusline").setup(opts)` | Sets the statusline. |
| `require("statusline").refresh()` | Redraws it, like after a toggle changed. |
