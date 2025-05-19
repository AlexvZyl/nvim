local git_char = "│"
--local git_char = '┃'

local signs = {
    add = { text = git_char },
    change = { text = git_char },
    delete = { text = git_char },
    topdelete = { text = git_char },
    changedelete = { text = git_char },
    untracked = { text = git_char },
}

require("gitsigns").setup({
    signs = signs,
    signs_staged = signs,
    signcolumn = true,
    numhl = false,
    signs_staged_enable = true,
})
