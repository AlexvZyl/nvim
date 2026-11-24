# winbar.nvim

A winbar with the file's icon and name.

## Setup

```lua
require("winbar").setup({
    exclude = { "help" },
    bars = {
        fugitive = {
            icon = "",
            name = function()
                return "Git"
            end,
        },
    },
})
```

## Commands

| Command | Function | Does |
|:---:|---|---|
| - | `require("winbar").setup(opts)` | Sets the winbar on every window. |
| - | `require("winbar").get_winbar()` | The winbar string of the current window. |
| - | `require("winbar").set_winbar()` | Updates the winbar of the current window. |
