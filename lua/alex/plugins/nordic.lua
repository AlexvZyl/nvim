require("nordic").load({
    cursorline = {
        theme = "dark",
    },
    telescope = {
        style = "classic",
    },
})

require("lualine").setup({
    options = { theme = "nordic" },
})
