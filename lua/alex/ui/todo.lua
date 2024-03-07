require('todo-comments').setup {
    signs = false,
    keywords = {
        FIX = { icon = '' },
        HACK = { icon = '󱠇' },
        TODO = { icon = '' },
        WARN = { icon = '' },
        PERF = { icon = '󱑂' },
        NOTE = { icon = '' },
        TEST = { icon = '󰙨' },
    },
    gui_style = {
        fg = "BOLD"
    },
    highlight = {
        keyword = 'fg',
        after = '',
        pattern = {
            [[.*<(KEYWORDS)\s*:]], -- default
            [[.*<(KEYWORDS)(\(\S+\))?:]],
        },
    },
    search = {
        pattern = [[\b(KEYWORDS)(\(\S+\))?:]],
    },
}

require('alex.keymaps').todo()
