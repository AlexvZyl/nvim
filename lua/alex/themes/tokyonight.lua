local TC = require 'tokyonight.colors'
local blend = require('tokyonight.util').blend

local transparent = true

local function on_highlights(H, C)
    -- Native
    H.MsgArea = { bg = C.bg_dark, fg = C.fg_dark }
    H.SpecialCmpBorder = { bg = C.bg }
    H.Pmenu = { bg = C.bg }
    -- Tree
    H.NvimTreeNormal = { bg = C.bg }
    H.NvimTreeNormalNC = { bg = C.bg }
    H.NvimTreeWinSeparator = { fg = C.bg_dark, bg = C.bg }
    -- Dashboard
    H.DashboardMruTitle = { fg = C.orange, bold = true }
    H.DashboardProjectTitle = { fg = C.orange, bold = true }
    H.DashboardProjectIcon = { fg = C.magenta, bold = true }
    -- Leap
    H.LeapBackdrop = {}
    H.LeapLabelPrimary = { bg = C.bg_dark, fg = C.red1 }
    H.LeapLabelSecondary = { bg = C.bg_dark, fg = C.red1 }
    -- Indent blankline
    H.IndentBlanklineContextChar = { fg = C.bg_highlight }
    H.IndentBlanklineChar = { fg = C.bg_highlight }
    -- LSP Saga
    H.LspSagaHoverBorder = { bg = C.bg }
    H.SagaNormal = { bg = C.bg }
    H.SagaBorder = { bg = C.bg, fg = C.orange }
    H.LspSagaRenameBorder = { fg = C.cyan, bg = C.bg }
    -- Telescope
    H.TelescopePromptTitle = { fg = C.bg_dark, bg = C.orange }
    H.TelescopePreviewTitle = { fg = C.bg_dark, bg = C.orange }
    --local prompt = blend(C.bg_dark, C.bg, 0.8)
    local prompt = TC.default.bg_dark
    H.TelescopePromptBorder = { fg = C.bg_dark, bg = prompt }
    H.TelescopePromptNormal = { bg = prompt }
    local preview = blend(C.bg_dark, C.bg, 0.15)
    H.TelescopeNormal = { bg = preview }
    H.TelescopeBorder = { fg = C.bg_dark, bg = preview }
    -- Noice
    H.NoiceCmdline = { bg = C.bg_dark }
    H.NoiceLspProgressTitle = { bg = C.bg }
    H.NoiceLspProgressClient = { bg = C.bg }
    H.NoiceLspProgressSpinner = { bg = C.bg }
    -- Copilot
    H.CopilotSuggestion = { fg = C.fg_gutter, italic = false }
    -- Debugger
    H.DapUINormal = { bg = C.bg_dark }
    -- Completion
    H.CmpItemKindVariable = { fg = C.cyan }
    -- Winbar.
    H.WinBar = { bg = C.bg_dark, fg = C.yellow }
    H.WinBarNC = { bg = C.bg_dark, fg = C.yellow }
    H.CustomWinBar = { fg = C.dark3 }
    H.CustomWinBarNC = { fg = C.dark3 }

    if transparent then
        H.LspSagaRenameBorder = { fg = C.cyan, bg = 'NONE' }
        H.Pmenu.bg = 'NONE'
        H.SpecialCmpBorder.bg = 'NONE'
        H.TroubleNormal = { bg = C.bg }
        H.WhichKeyFloat = { bg = C.bg }
        H.WhichKeyBorder = { fg = C.bg_dark, bg = C.bg }
    end

    -- Custom highlights.
    H.TroubleWinBar = { bg = C.bg_dark, fg = C.yellow }
end

require('tokyonight').load {
    style = 'night',
    on_highlights = on_highlights,
    on_colors = function(_) end,
    transparent = transparent,
}

require('lualine').setup {
    options = { theme = 'tokyonight' },
}
