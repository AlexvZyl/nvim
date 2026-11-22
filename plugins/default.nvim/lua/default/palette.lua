local U = require("default.utils")

local M = {}

-- NOTE: Using builtin neovim colors.
M = {
    -- Colors.
    red = U.get_color_hex("LightCoral"),
    green = U.get_color_hex("NvimLightGreen"),
    yellow = U.get_color_hex("NvimLightYellow"),
    magenta = U.get_color_hex("NvimLightMagenta"),
    orange = U.get_color_hex("LightSalmon"),
    blue = U.get_color_hex("LightSkyBlue"),
    cyan = U.get_color_hex("NvimLightCyan"),

    -- Blacks/grays.
    black = U.get_color_hex("NvimDarkGray1"),
    gray0 = U.get_color_hex("NvimDarkGray2"),
    gray1 = U.get_color_hex("NvimDarkGray3"),
    gray2 = U.get_color_hex("NvimDarkGray4"),
    gray3 = "#55585e", -- Slightly lighter than gray2.  TODO: Automate this.

    -- Whites.
    white0 = U.get_color_hex("NvimLightGray1"),
    white1 = U.get_color_hex("NvimLightGray2"),
    white2 = U.get_color_hex("NvimLightGray3"),
    white3 = U.get_color_hex("NvimLightGray4"),
}

-- Extensions.
M.fg = M.white0
M.bg = M.gray0
M.bg_dark = M.black
M.bg_float = U.blend(M.bg, 0.55, M.bg_dark)
M.fg_dim = U.blend(M.white2, 0.65, M.bg_dark)
M.bg_highlight = M.gray1
M.diff = {
    add = U.blend(M.green, 0.2, M.bg_dark),
    delete = U.blend(M.red, 0.2, M.bg_dark),
    change = U.blend(M.blue, 0.2, M.bg_dark),
    text = M.blue,
}

function M.print_palette()
    print(vim.inspect(M))
end

return M
