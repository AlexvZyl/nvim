# winbar.nvim

A winbar with the file's icon and name.

## Setup

```lua
require("winbar").setup({
    exclude = { "help" },
    bars = {
        fugitive = {
            icon = "",
            name = function()
                return "Git"
            end,
        },
    },
})
```

## Commands

| Function | Does |
|---|---|
| `require("winbar").set_winbar()` | Updates the winbar of the current window. |
