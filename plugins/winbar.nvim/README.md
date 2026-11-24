# winbar.nvim

A winbar with the file's icon, parent directory, name and modified state. Requires
[nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons).

## Setup

```lua
require("winbar").setup({
    -- Filetypes left alone, like ones that set their own.
    exclude = {},
    -- Bars by filetype or buftype, merged over the built-in ones (qf, oil, man, terminal, ...).
    bars = {
        fugitive = {
            icon = "",
            name = function()
                return "Git"
            end,
            hide_modified = true,
        },
    },
})
```

## Functions

| Function | Does |
|---|---|
| `require("winbar").setup(opts)` | Sets the winbar on every window. |
| `require("winbar").set_winbar()` | Updates it for the current window. |
