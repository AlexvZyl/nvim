local char = "┆"

require("ibl").setup({
    exclude = {
        filetypes = { "help", "markdown", "lazy" },
    },
    scope = {
        enabled = true,
        show_start = false,
        show_end = false,
        -- char = { context_char },
        char = { char },
        highlight = { "IndentBlanklineContextChar", "IndentBlanklineContextChar" },
    },
    indent = {
        char = { char },
        highlight = { "IndentBlanklineChar", "IndentBlanklineChar" },
    },
})
