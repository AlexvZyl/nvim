local P = require('default.palette')


local function create_group(mode_color)
    local DEFAULT_SECTION = {
        fg = P.fg_dim,
        bg = P.bg_dark,
    }
    return {
        a = { fg = P.bg_dark, bg = mode_color, gui = "bold" },
        b = DEFAULT_SECTION,
        c = DEFAULT_SECTION,
    }
end


return {
    normal = create_group(P.blue),
    visual = create_group(P.red),
    replace = create_group(P.red),
    command = create_group(P.orange),
    insert = create_group(P.green),
    interactive = create_group(P.magenta),
    terminal = create_group(P.yellow),
}
