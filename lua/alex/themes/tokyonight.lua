local TC = require 'tokyonight.colors'

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
    H.IndentBlanklineContextChar = { fg = C.bg_highlight }
    H.IndentBlanklineChar = { fg = C.bg_highlight }
    H.TelescopePromptTitle = { fg = C.bg_dark, bg = C.orange }
    H.TelescopePreviewTitle = { fg = C.bg_dark, bg = C.orange }
    H.MsgArea = { bg = C.bg_dark, fg = C.fg_dark }

    H.LspSagaHoverBorder = { fg = C.fg }
    H.SagaBorder = { fg = C.fg }

    --H.TelescopeBorder = { fg = C.fg_dark, bg = C.bg_dark }
    H.TelescopeBorder = { fg = TC.default.bg, bg = C.bg_dark }
    --H.TelescopePromptBorder = { fg = C.fg_dark, bg = C.bg }
    H.TelescopePromptBorder = { fg = TC.default.bg, bg = C.bg }

    H.TelescopePromptNormal = { bg = C.bg }
    H.NoiceCmdline = { bg = C.bg_dark }

    H.CopilotSuggestion = { fg = C.fg_gutter, italic = false }
end

require('tokyonight').load {
    style = 'night',
    on_highlights = on_highlights,
    on_colors = function(_) end,
}

require('lualine').setup {
    options = { theme = 'tokyonight' },
}
