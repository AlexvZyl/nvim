local M = {}

local U = require("alex.utils")

local transparent = false

local function get_bg(color)
    return transparent and "NONE" or color
end

-- TODO: Read these colors in at startup from the builtin groups.
-- Not really sure if it is even possible.
M.palette = {
    -- Colors.
    red = "#f08080",
    green = "#b3f6c0",
    yellow = "#fce094",
    magenta = "#ffcaff",
    orange = "#ffa07a",
    blue = "#87cefa",
    cyan = "#8cf8f7",

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

-- Extensions.
M.palette.fg = M.palette.white0
M.palette.bg = M.palette.gray0
M.palette.bg_dark = M.palette.black
M.palette.bg_float = U.blend(M.palette.bg, 0.55, M.palette.bg_dark)
M.palette.fg_dim = U.blend(M.palette.white2, 0.65, M.palette.bg_dark)
M.palette.bg_highlight = M.palette.gray1

function M.init()
    U.set_highlights_table({
        -- Git
        Added = { fg = M.palette.green },
        Removed = { fg = M.palette.red },
        Changed = { fg = M.palette.blue },
        Normal = { bg = get_bg(M.palette.bg) },

        -- Native UI.
        Visual = { bg = M.palette.bg_highlight },
        WinBar = {
            fg = M.palette.fg_dim,
            bg = get_bg(M.palette.bg_float),
            underline = true,
            sp = M.palette.bg_dark,
        },
        WinBarNC = { link = "WinBar" },
        Pmenu = { link = "Normal" },
        WinSeparator = { fg = M.palette.bg_dark, bg = get_bg(M.palette.bg) },
        NormalFloat = { fg = M.palette.fg, bg = get_bg(M.palette.bg) },
        FloatBorder = { fg = M.palette.fg, bg = get_bg(M.palette.bg) },
        LineNR = { fg = M.palette.gray2, bg = get_bg(M.palette.bg) },
        CursorLineNR = { fg = M.palette.white0, bg = get_bg(M.palette.bg), bold = true },
        QuickFixFilename = { fg = M.palette.fg },
        QuickFixLine = { fg = M.palette.fg },
        LspInfoBorder = { link = "FloatBorder" },

        -- Syntax tweaks.
        MatchParen = { bg = get_bg(M.palette.bg), underline = true },
        Statement = { fg = M.palette.orange, bold = false },
        Comment = { fg = M.palette.gray2, bold = false },
        Title = { fg = M.palette.yellow, bold = true },
        Constant = { bold = false },
        ["@markup.heading.2"] = { fg = M.palette.orange, bold = true },
        ["@markup.heading.3"] = { fg = M.palette.orange },
        ["@markup.heading.4"] = { link = "@markup.heading.3" },
        ["@markup.heading.5"] = { link = "@markup.heading.3" },
        ["@markup.heading.6"] = { link = "@markup.heading.3" },
        Number = { fg = M.palette.magenta },
        Boolean = { fg = M.palette.magenta },

        -- Indent blankline.
        IndentBlanklineChar = { fg = U.blend(M.palette.gray1, 0.7, M.palette.bg) },
        IndentBlanklineContextChar = { link = "IndentBlanklineChar" },

        -- Diagnostics.
        DiagnosticError = { fg = M.palette.red },
        DiagnosticWarn = { fg = M.palette.yellow },
        DiagnosticHint = { fg = M.palette.green },
        DiagnosticOk = { fg = M.palette.green },
        DiagnosticInfo = { fg = M.palette.blue },
        DiagnosticSignError = { fg = M.palette.red, bold = true },
        DiagnosticSignWarn = { fg = M.palette.yellow, bold = true },
        DiagnosticSignHint = { fg = M.palette.green, bold = true },
        DiagnosticSignOk = { fg = M.palette.green, bold = true },
        DiagnosticSignInfo = { fg = M.palette.blue, bold = true },
        DiagnosticUnderlineError = { sp = M.palette.red, underline = true, undercurl = false },
        DiagnosticUnderlineWarn = { sp = M.palette.yellow, underline = true, undercurl = false },
        DiagnosticUnderlineHint = { sp = M.palette.green, underline = true, undercurl = false },
        DiagnosticUnderlineOk = { sp = M.palette.green, underline = true, undercurl = false },
        DiagnosticUnderlineInfo = { sp = M.palette.blue, underline = true, undercurl = false },
        DiagnosticVirtualTextError = {
            fg = M.palette.red,
            bg = get_bg(M.palette.bg),
            underline = true,
        },
        DiagnosticVirtualTextWarn = {
            fg = M.palette.yellow,
            bg = get_bg(M.palette.bg),
            underline = true,
        },
        DiagnosticVirtualTextHint = {
            fg = M.palette.green,
            bg = get_bg(M.palette.bg),
            underline = true,
        },
        DiagnosticVirtualTextOk = {
            fg = M.palette.green,
            bg = get_bg(M.palette.bg),
            underline = true,
        },
        DiagnosticVirtualTextInfo = {
            fg = M.palette.blue,
            bg = get_bg(M.palette.bg),
            underline = true,
        },
        DiagnosticVirtualLinesError = { fg = M.palette.red, bg = M.palette.bg_float },
        DiagnosticVirtualLinesWarn = { fg = M.palette.yellow, bg = M.palette.bg_float },
        DiagnosticVirtualLinesHint = { fg = M.palette.green, bg = M.palette.bg_float },
        DiagnosticVirtualLinesOk = { fg = M.palette.green, bg = M.palette.bg_float },
        DiagnosticVirtualLinesInfo = { fg = M.palette.blue, bg = M.palette.bg_float },

        -- Whichkey.
        WhichKeyNormal = { bg = M.palette.bg_float },
        WhichKeyTitle = { bg = M.palette.bg_float, fg = M.palette.yellow, bold = true },
        WhichKeyBorder = { bg = M.palette.bg_float, fg = M.palette.bg_dark },

        -- Dashboard.
        DashboardHeader = { fg = M.palette.yellow },
        DashboardFooter = { fg = M.palette.cyan },
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
        NvimTreeSpecialFile = { fg = M.palette.yellow, bold = false },

        -- Telescope.
        TelescopePromptPrefix = { fg = M.palette.yellow, bg = get_bg(M.palette.bg) },
        TelescopeTitle = { fg = M.palette.bg_dark, bg = M.palette.orange },
        TelescopeMultiIcon = { fg = M.palette.fg },

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
        NotifyBackground = { bg = get_bg(M.palette.bg) },

        -- Noice.
        NoiceCmdlinePopupBorder = { fg = M.palette.cyan },
        NoiceFormatProgressDone = { bg = M.palette.green },
        NoiceCmdlineIcon = { fg = M.palette.yellow },
        NoiceCmdlineIconSearch = { fg = M.palette.yellow, bg = M.palette.bg_dark },
        NoiceCmdline = { bg = M.palette.bg_dark },

        -- Todo comments
        TodoFgTODO = { fg = M.palette.cyan, bold = true },

        -- Lazy.
        LazyProgressDone = { fg = M.palette.green },

        -- HACK:
        luaParenError = { link = "Normal" },
        markdownError = { link = "Normal" },
    })
end

function M.setup_lualine()
    local function create_group(mode_color)
        local DEFAULT_SECTION = {
            fg = M.palette.fg_dim,
            bg = M.palette.bg_dark,
        }
        return {
            a = { fg = M.palette.bg_dark, bg = mode_color, gui = "bold" },
            b = DEFAULT_SECTION,
            c = DEFAULT_SECTION,
        }
    end

    require("lualine").setup({
        options = {
            theme = {
                normal = create_group(M.palette.blue),
                visual = create_group(M.palette.red),
                replace = create_group(M.palette.red),
                command = create_group(M.palette.orange),
                insert = create_group(M.palette.green),
                interactive = create_group(M.palette.gray0),
                terminal = create_group(M.palette.gray0),
            },
        },
    })
end

M.init()

return M
