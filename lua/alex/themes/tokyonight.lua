local function on_highlights(H, C)
    H.NvimTreeNormal = { bg = C.bg }
    H.NvimTreeNormalNC = { bg = C.bg }
    H.NvimTreeWinSeparator = { fg = C.bg_dark, bg = C.bg }
    H.DashboardMruTitle = { fg = C.orange, bold = true }
    H.DashboardProjectTitle = { fg = C.orange, bold = true }
    H.DashboardProjectIcon = { fg = C.magenta, bold = true }
end

require('tokyonight').load {
    style = 'night',
    on_highlights = on_highlights,
    on_colors = function(_) end
}

require('lualine').setup {
    options = { theme = 'tokyonight' },
}
