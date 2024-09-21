local M = {}

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

    U.set_highlight("IndentBlanklineChar", { fg = M.palette.gray1 })
    U.set_highlight("IndentBlanklineContextChar", { link = "IndentBlanklineChar" })

    U.set_highlight("WinBar", { fg = M.palette.white3, bg = M.palette.bg })
    U.set_highlight("WinBarNC", { link = "WinBar" })
    U.set_highlight("Pmenu", { link = "Normal" })
    U.set_highlight("WinSeparator", { fg = M.palette.bg_dark, bg = M.palette.bg })

    U.set_highlight("DiagnosticError", { fg = M.palette.red })
    U.set_highlight("DiagnosticWarn", { fg = M.palette.yellow })
    U.set_highlight("DiagnosticHint", { fg = M.palette.green })
    U.set_highlight("DiagnosticOk", { fg = M.palette.green })

    U.set_highlight("WhichKeyNormal", { bg = M.palette.bg })
    U.set_highlight("WhichKeyBorder", { bg = M.palette.bg, fg = M.palette.bg_dark })
end

function M.setup_lualine()
    local U = require("alex.utils.neovim")
    if not U.is_default() then
        return
    end

    local default_section = { fg = M.palette.white3, bg = M.palette.bg_dark }
    local default = {
        normal = { a = { fg = M.palette.bg_dark, bg = M.palette.blue0, gui = "bold" }, b = default_section, c = default_section },
        visual = { a = { fg = M.palette.bg_dark, bg = M.palette.red, gui = "bold" }, b = default_section, c = default_section },
        replace = { a = { fg = M.palette.bg_dark, bg = M.palette.red, gui = "bold" }, b = default_section, c = default_section },
        command = { a = { fg = M.palette.bg_dark, bg = M.palette.orange, gui = "bold" }, b = default_section, c = default_section },
        insert = { a = { fg = M.palette.bg_dark, bg = M.palette.green, gui = "bold" }, b = default_section, c = default_section },
        inactive = { a = { fg = M.palette.bg_dark, bg = M.palette.gray0, gui = "bold" }, b = default_section, c = default_section },
        terminal = { a = { fg = M.palette.bg_dark, bg = M.palette.gray0, gui = "bold" }, b = default_section, c = default_section },
    }
    require("lualine").setup({
        options = { theme = default }
    })
end

init()

return M
