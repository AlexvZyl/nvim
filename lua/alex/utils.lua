local M = {}

-- LUA UTILS

function M.file_exists(file)
    local f = io.open(file, 'r')
    if f then
        io.close(f)
        return true
    else
        return false
    end
end

function M.length(table)
    local count = 0
    for _, _ in ipairs(table) do
        count = count + 1
    end
    return count
end

-- BORDERS

M.border_chars_round = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }
M.border_chars_none = { '', '', '', '', '', '', '', '' }
M.border_chars_empty = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' }
M.border_chars_inner_thick = { ' ', '▄', ' ', '▌', ' ', '▀', ' ', '▐' }
M.border_chars_outer_thick = { '▛', '▀', '▜', '▐', '▟', '▄', '▙', '▌' }
M.border_chars_cmp_items = { '▛', '▀', '▀', ' ', '▄', '▄', '▙', '▌' }
M.border_chars_cmp_doc = { '▀', '▀', '▀', ' ', '▄', '▄', '▄', '▏' }
M.border_chars_outer_thin = { '🭽', '▔', '🭾', '▕', '🭿', '▁', '🭼', '▏' }
M.border_chars_inner_thin = { ' ', '▁', ' ', '▏', ' ', '▔', ' ', '▕' }
M.border_chars_outer_thin_telescope = { '▔', '▕', '▁', '▏', '🭽', '🭾', '🭿', '🭼' }
M.border_chars_outer_thick_telescope = { '▀', '▐', '▄', '▌', '▛', '▜', '▟', '▙' }

M.top_and_bottom = '🮀'

M.bottom_thin = '▁'
M.top_thin = '▔'
M.left_thin = '▏'
M.right_thin = '▕'

M.left_thick = '▎'
M.right_thick = '🮇'
M.full_block = '█'

M.top_right_thin = '🭾'
M.top_left_thin = '🭽'
M.bottom_left_thin = '🭼'
M.bottom_right_thin = '🭿'

M.top_left_round = '╭'
M.top_right_round = '╮'
M.bottom_right_round = '╯'
M.bottom_left_round = '╰'

M.vertical_default = '│'
M.horizontal_default = '─'

function M.get_border_chars(desc)
    if desc == 'completion' then return M.border_chars_round end
    if desc == 'cmdline' then return M.border_chars_round end
    if desc == 'search' then return M.border_chars_round end
    if desc == 'float' then return M.border_chars_outer_thin end

    if desc == 'lsp' then
        if vim.g.colors_name == 'nordic' then return M.border_chars_outer_thin end
        return M.border_chars_round
    end

    -- Defaults
    if vim.g.colors_name == 'nordic' then return M.border_chars_outer_thin end
    if vim.g.colors_name == 'tokyonight' then return M.border_chars_round end
end

-- ICONS

M.diagnostic_signs = {
    error = ' ',
    warning = ' ',
    warn = ' ',
    info = ' ',
    information = ' ',
    hint = '󱤅 ',
    other = '󰠠 ',
}

M.kind_icons = {
    Text = ' ',
    Method = ' ',
    Function = '󰊕 ',
    Constructor = ' ',
    Field = ' ',
    Variable = ' ',
    Class = '󰠱 ',
    Interface = ' ',
    Module = '󰏓 ',
    Property = ' ',
    Unit = ' ',
    Value = ' ',
    Enum = ' ',
    EnumMember = ' ',
    Keyword = '󰌋 ',
    Snippet = '󰲋 ',
    Color = ' ',
    File = ' ',
    Reference = ' ',
    Folder = ' ',
    Constant = '󰏿 ',
    Struct = '󰠱 ',
    Event = ' ',
    Operator = ' ',
    TypeParameter = '󰘦 ',
    TabNine = '󰚩 ',
    Copilot = ' ',
    Unknown = ' ',
}

return M
