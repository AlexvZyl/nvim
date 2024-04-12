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
    H.LspSagaHoverBorder = { fg = C.fg }
    H.SagaBorder = { fg = C.fg }
    H.SagaNormal = { bg = C.bg }
    H.SagaBorder = { bg = C.bg, fg = C.orange }
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
    -- Copilot
    H.CopilotSuggestion = { fg = C.fg_gutter, italic = false }
    -- Debugger
    H.DapUINormal = { bg = C.bg_dark }
    -- Completion
    H.CmpItemKindVariable = { fg = C.cyan }

    if transparent then
        H.LspSagaHoverBorder.bg = 'NONE'
        H.SagaBorder.bg = 'NONE'
        H.SagaNormal.bg = 'NONE'
        H.SagaBorder.bg = 'NONE'
        H.Pmenu.bg = 'NONE'
        H.SpecialCmpBorder.bg = 'NONE'
        H.HoverNormal = { bg = 'NONE' }
        H.TroubleNormal = { bg = C.bg }
        H.WhichKeyFloat = { bg = C.bg }
        H.WhichKeyBorder = { fg = C.bg_dark, bg = C.bg }
    end
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
