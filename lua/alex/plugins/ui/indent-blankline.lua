--local context_char = '┃'
--local char = '┋'
local context_char = '│'
local char = '┆'

require('ibl').setup {
    exclude = {
        filetypes = { 'NvimTree', 'startify', 'dashboard', 'help', 'markdown' },
    },
    scope = {
        enabled = true,
        show_start = false,
        show_end = false,
        char = context_char,
        highlight = 'IndentBlanklineContextChar',
    },
    indent = {
        char = char,
        highlight = 'IndentBlanklineChar',
    },
}
