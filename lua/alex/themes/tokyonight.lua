local function on_highlights(H, C)
    H.NvimTreeNormal = { bg = C.bg }
    H.NvimTreeNormalNC = { bg = C.bg }
    H.NvimTreeWinSeparator = { fg = C.bg_dark, bg = C.bg }
    H.DashboardMruTitle = { fg = C.orange, bold = true }
    H.DashboardProjectTitle = { fg = C.orange, bold = true }
    H.DashboardProjectIcon = { fg = C.magenta, bold = true }
    H.SagaNormal = { bg = C.bg }
    H.SagaBorder = { bg = C.bg, fg = C.orange }
    H.SpecialCmpBorder = { bg = C.bg }
    H.Pmenu = { bg = C.bg }
    H.LeapBackdrop = {}
    H.LeapLabelPrimary = { bg = C.bg_dark, fg = C.red1 }
    H.LeapLabelSecondary = { bg = C.bg_dark, fg = C.red1 }
    H.IndentBlanklineContextChar = { fg = C.fg_gutter }
end

require('tokyonight').load {
    style = 'night',
    on_highlights = on_highlights,
    on_colors = function(_) end,
}

require('lualine').setup {
    options = { theme = 'tokyonight' },
}
