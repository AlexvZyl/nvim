local M = {}

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
M.border_chars_top_only = { '', M.top_thin, '', '', '', ' ', '', '' }

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
    Value = ' ',
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

function M.get_border_chars(desc)
    local T = require 'alex.utils.theme'

    if vim.g.neovide then
        -- Hmmmm
    end

    if desc == 'completion' then return M.border_chars_round end
    if desc == 'cmdline' then return M.border_chars_round end
    if desc == 'search' then return M.border_chars_round end
    if desc == 'float' then return M.border_chars_outer_thin end
    if desc == 'telescope' then return M.border_chars_outer_thin_telescope end

    if desc == 'lsp' then
        if T.is_nordic() then return M.border_chars_outer_thin end
        return M.border_chars_round
    end

    -- Defaults
    if T.is_nordic() then return M.border_chars_outer_thin end
    if T.is_tokyonight() then return M.border_chars_round end

    return M.border_chars_round
end

return M
