local M = {}

-- TODO: Read these colors in at startup.
M.palette = {
    -- Colors.
    red = "#f08080",
    green = "#b3f6c0",
    yellow = "#fce094",
    magenta = "#ffcaff",
    orange = "#ffa07a",
    blue0 = "#87cefa",
    blue1 = "#b0e2ff",
    cyan = "#20b2aa",

    -- Blacks/grays.
    black = "#07080d",
    gray0 = "#14161b",
    gray1 = "#2c2e33",
    gray2 = "#4f5258",

    -- Whites.
    white0 = "#eef1f8",
    white1 = "#e0e2ea",
    white2 = "#c4c6cd",
    white3 = "#9b9ea4",
}
M.palette.fg = M.palette.white0
M.palette.bg = M.palette.gray0
M.palette.bg_dark = M.palette.black

local function init()
    local U = require("alex.utils.neovim")

    U.set_highlights_table({
        -- Native UI.
        WinBar = { fg = M.palette.white2, bg = M.palette.bg },
        WinBarNC = { fg = M.palette.white2, bg = M.palette.bg },
        Pmenu = { link = "Normal" },
        WinSeparator = { fg = M.palette.bg_dark, bg = M.palette.bg },
        NormalFloat = { fg = M.palette.fg, bg = M.palette.bg },
        FloatBorder = { fg = M.palette.fg, bg = M.palette.bg },
        LineNR = { fg = M.palette.gray2, bg = M.palette.bg },
        CursorLineNR = { fg = M.palette.white0, bg = M.palette.bg, bold = true },

        -- Syntax tweaks.
        MatchParen = { bg = M.palette.bg, underline = true },
        Statement = { fg = M.palette.orange, bold = false },
        Comment = { fg = M.palette.gray2, bold = false },
        Title = { fg = M.palette.yellow, bold = true },
        ["@markup.heading.2"] = { fg = M.palette.orange },
        ["@markup.heading.3"] = { link = "markup.heading.2" },
        ["@markup.heading.4"] = { link = "markup.heading.2" },
        ["@markup.heading.5"] = { link = "markup.heading.2" },

        -- Indent blankline.
        IndentBlanklineChar = { fg = M.palette.gray1 },
        IndentBlanklineContextChar = { link = "IndentBlanklineChar" },

        -- Diagnostics.
        DiagnosticError = { fg = M.palette.red },
        DiagnosticWarn = { fg = M.palette.yellow },
        DiagnosticHint = { fg = M.palette.green },
        DiagnosticOk = { fg = M.palette.green },
        DiagnosticUnderlineError = { sp = M.palette.red, underline = false, undercurl = true },
        DiagnosticUnderlineWarn = { sp = M.palette.yellow, underline = false, undercurl = true },
        DiagnosticUnderlineHint = { sp = M.palette.green, underline = false, undercurl = true },
        DiagnosticUnderlineOk = { sp = M.palette.green, underline = false, undercurl = true },

        -- Whichkey.
        WhichKeyNormal = { bg = M.palette.bg },
        WhichKeyBorder = { bg = M.palette.bg, fg = M.palette.bg_dark },

        -- Dashboard.
        DashboardHeader = { fg = M.palette.yellow },
        DashboardFooter = { fg = M.palette.blue1 },
        DashboardProjectTitle = { fg = M.palette.orange },
        DashboardMruTitle = { fg = M.palette.orange },

        -- Tree.
        NvimTreeModifiedIcon = { fg = M.palette.gray2 },
        NvimTreeGitDirtyIcon = { link = "NvimTreeModifiedIcon" },
        NvimTreeGitStagedIcon = { link = "NvimTreeModifiedIcon" },
        NvimTreeGitDeletedIcon = { link = "NvimTreeModifiedIcon" },
        NvimTreeGitIgnoredIcon = { link = "NvimTreeModifiedIcon" },
        NvimTreeGitNewIcon = { link = "NvimTreeModifiedIcon" },
        NvimTreeGitRenamedIcon = { link = "NvimTreeModifiedIcon" },
        NvimTreeRootFolder = { fg = M.palette.white3 },

        -- Telescope.
        TelescopePromptPrefix = { fg = M.palette.yellow, bg = M.palette.bg },

        -- Notify.
        NotifyINFOTitle = { fg = M.palette.green },
        NotifyINFOIcon = { fg = M.palette.green },
        NotifyINFOBorder = { fg = M.palette.green },
        NotifyINFOBody = { fg = M.palette.fg },
        NotifyWARNTitle = { fg = M.palette.yellow },
        NotifyWARNIcon = { fg = M.palette.yellow },
        NotifyWARNBorder = { fg = M.palette.yellow },
        NotifyWARNBody = { fg = M.palette.fg },
        NotifyERRORTitle = { fg = M.palette.red },
        NotifyERRORIcon = { fg = M.palette.red },
        NotifyERRORBorder = { fg = M.palette.red },
        NotifyERRORBody = { fg = M.palette.fg },
    })
end

function M.setup_lualine()
    local U = require("alex.utils.neovim")
    if not U.is_default() then return end

    local default_section = { fg = M.palette.white3, bg = M.palette.bg_dark }
    local default = {
        normal = {
            a = { fg = M.palette.bg_dark, bg = M.palette.blue0, gui = "bold" },
            b = default_section,
            c = default_section,
        },
        visual = {
            a = { fg = M.palette.bg_dark, bg = M.palette.red, gui = "bold" },
            b = default_section,
            c = default_section,
        },
        replace = {
            a = { fg = M.palette.bg_dark, bg = M.palette.red, gui = "bold" },
            b = default_section,
            c = default_section,
        },
        command = {
            a = { fg = M.palette.bg_dark, bg = M.palette.orange, gui = "bold" },
            b = default_section,
            c = default_section,
        },
        insert = {
            a = { fg = M.palette.bg_dark, bg = M.palette.green, gui = "bold" },
            b = default_section,
            c = default_section,
        },
        inactive = {
            a = { fg = M.palette.bg_dark, bg = M.palette.gray0, gui = "bold" },
            b = default_section,
            c = default_section,
        },
        terminal = {
            a = { fg = M.palette.bg_dark, bg = M.palette.gray0, gui = "bold" },
            b = default_section,
            c = default_section,
        },
    }
    require("lualine").setup({
        options = { theme = default },
    })
end

init()

return M
