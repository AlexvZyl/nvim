local M = {}

-- Single chars.
M.bottom_thin = "▁"
M.top_thin = "▔"
M.left_thin = "▏"
M.right_thin = "▕"
M.left_thick = "▎"
M.right_thick = "🮇"
M.full_block = "█"
M.top_right_thin = "🭾"
M.top_left_thin = "🭽"
M.bottom_left_thin = "🭼"
M.bottom_right_thin = "🭿"
M.top_left_round = "╭"
M.top_right_round = "╮"
M.bottom_right_round = "╯"
M.bottom_left_round = "╰"
M.vertical_default = "│"
M.horizontal_default = "─"
M.small_circle = "•"

-- Border chars.
M.border_chars_round = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
M.border_chars_none = { "", "", "", "", "", "", "", "" }
M.border_chars_empty = { " ", " ", " ", " ", " ", " ", " ", " " }
M.border_chars_inner_thick = { " ", "▄", " ", "▌", " ", "▀", " ", "▐" }
M.border_chars_outer_thick = { "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" }
M.border_chars_cmp_items = { "▛", "▀", "▀", " ", "▄", "▄", "▙", "▌" }
M.border_chars_cmp_doc = { "▀", "▀", "▀", " ", "▄", "▄", "▄", "▏" }
M.border_chars_outer_thin = { "🭽", "▔", "🭾", "▕", "🭿", "▁", "🭼", "▏" }
M.border_chars_inner_thin = { " ", "▁", " ", "▏", " ", "▔", " ", "▕" }
M.border_chars_top_only_thin = { " ", M.top_thin, " ", " ", " ", " ", " ", " " }
M.border_chars_top_only_normal = { "", M.horizontal_default, "", "", "", " ", "", "" }

-- Telscope chars.
M.border_helix_telescope = { "─", "│", "─", "│", "┌", "┐", "┘", "└" }
M.border_chars_outer_thick_telescope = { "▀", "▐", "▄", "▌", "▛", "▜", "▟", "▙" }
M.border_chars_outer_thin_telescope = { "▔", "▕", "▁", "▏", "🭽", "🭾", "🭿", "🭼" }
M.border_chars_telescope_default = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
M.border_chars_telescope_prompt_thin = { "▔", "▕", " ", "▏", "🭽", "🭾", "▕", "▏" }
M.border_chars_telescope_vert_preview_thin =
    { " ", "▕", "▁", "▏", "▏", "▕", "🭿", "🭼" }
M.border_chars_telescope_combine_top = { "─", "│", " ", "│", "╭", "╮", "│", "│" }
M.border_chars_telescope_combine_bottom = { "─", "│", "─", "│", "├", "┤", "╯", "╰" }

-- Icons.
M.diagnostic_signs = {
    error = " ",
    warning = " ",
    warn = " ",
    info = " ",
    information = " ",
    hint = " ",
    other = " ",
}
M.kind_icons = {
    Text = " ",
    Method = " ",
    Function = "󰊕 ",
    Constructor = " ",
    Field = " ",
    Variable = " ",
    Class = "󰠱 ",
    Interface = " ",
    Module = "󰏓 ",
    Property = " ",
    Unit = " ",
    Value = " ",
    Enum = " ",
    EnumMember = " ",
    Keyword = "󰌋 ",
    Snippet = "󰲋 ",
    Color = " ",
    File = " ",
    Reference = " ",
    Folder = " ",
    Constant = "󰏿 ",
    Struct = "󰠱 ",
    Event = " ",
    Operator = " ",
    TypeParameter = "󰘦 ",
    TabNine = "󰚩 ",
    Copilot = " ",
    Unknown = " ",
    Recording = " ",
    None = "  ",
}

return M
