--local context_char = '┃'
--local char = '┋'
local context_char = '│'
local char = '┆'

require('indent_blankline').setup {
    show_end_of_line = true,
    show_current_context = true,
    show_current_context_start = false,
    filetype_exclude = { 'NvimTree', 'startify', 'dashboard', 'help', 'markdown' },
    context_char = context_char,
    char = char,
}
