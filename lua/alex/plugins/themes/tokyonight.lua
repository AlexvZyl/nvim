local TC = require("tokyonight.colors")
local default = require("tokyonight.colors.moon")
local blend = require("tokyonight.util").blend

local transparent = true
if vim.g.neovide then
    transparent = false
end

local function on_highlights(H, C)
    -- Native
    H.MsgArea = { bg = C.bg_dark, fg = C.fg_dark }
    H.SpecialCmpBorder = { bg = C.bg }
    H.Pmenu = { bg = C.bg }
    -- Tree
    H.NvimTreeNormal = { bg = C.bg }
    H.NvimTreeNormalNC = { bg = C.bg }
    H.NvimTreeWinSeparator = { fg = C.bg_dark, bg = C.bg }
    H.NvimTreeWindowPicker = { fg = C.bg_dark, bg = C.cyan }
    -- Dashboard
    H.DashboardMruTitle = { fg = C.orange, bold = true }
    H.DashboardProjectTitle = { fg = C.orange, bold = true }
    H.DashboardProjectIcon = { fg = C.magenta, bold = true }
    H.DashboardFiles = { fg = C.fg }
    -- Leap
    H.LeapBackdrop = {}
    H.LeapLabelPrimary = { bg = C.bg_dark, fg = C.red1 }
    H.LeapLabelSecondary = { bg = C.bg_dark, fg = C.red1 }
    -- Indent blankline
    H.IndentBlanklineContextChar = { fg = C.bg_highlight }
    H.IndentBlanklineChar = { fg = C.bg_highlight }

    -- Telescope
    H.TelescopePromptTitle = { fg = C.bg_dark, bg = C.orange }
    H.TelescopePreviewTitle = { fg = C.bg_dark, bg = C.orange }
    local prompt = default.bg_dark
    H.TelescopePromptBorder = { fg = C.bg_dark, bg = prompt }
    H.TelescopePromptNormal = { bg = prompt }
    local preview = blend(C.bg_dark, 0.15, C.bg)
    H.TelescopeNormal = { bg = preview }
    H.TelescopeBorder = { fg = C.bg_dark, bg = preview }

    -- Noice
    H.NoiceCmdline = { bg = C.bg_dark }
    H.NoiceLspProgressTitle = { bg = C.bg }
    H.NoiceLspProgressClient = { bg = C.bg }
    H.NoiceLspProgressSpinner = { bg = C.bg }

    -- Debugger
    H.DapUINormal = { bg = C.bg_dark }
    -- Completion
    H.CmpItemKindVariable = { fg = C.cyan }
    H.CmpItemKindFile = { fg = C.yellow }

    if transparent then
        H.NormalFloat = { bg = C.bg }
        H.FloatBorder = { fg = C.blue1, bg = C.bg }
        H.LspInfoBorder = { fg = C.blue1, bg = C.bg }
        H.Pmenu.bg = "NONE"
        H.SpecialCmpBorder.bg = "NONE"
        H.NoicePopup = { bg = "NONE" }
        H.NoicePopupBorder = { bg = "NONE" }
    end

    -- Whichkey.
    H.WhichKeyBorder = { fg = C.bg_dark, bg = C.bg }
    H.WhichKeyNormal = { bg = C.bg }
    H.WhichKeyTitle = { fg = C.yellow, bg = C.bg_dark, bold = true }

    -- Winbar.
    H.CustomWinBar = { fg = C.comment }
    H.CustomWinBarNC = { fg = C.comment }
    H.WinBar = { fg = C.comment }
    H.WinBarNC = { fg = C.comment }
end

require("tokyonight").load({
    style = "night",
    on_highlights = on_highlights,
    on_colors = function(_) end,
    transparent = transparent,
})

require("lualine").setup({
    options = { theme = "tokyonight-night" },
})
