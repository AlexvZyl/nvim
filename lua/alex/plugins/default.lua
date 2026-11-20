local P = require("default.palette")
local U = require("default.utils")


local green_dim = 0.20

require("default").load({
    overrides = {
        Comment = {
            italic = true,
            fg = P.gray2,
        },
        DiagnosticUnnecessary = {
            fg = P.white3,
            italic = false,
        },
        ["@string.special.url.gdscript"] = {
            underline = false,
        },
        ReviewAdd = {
            bg = U.blend(P.diff.add, green_dim, P.bg),
        },
        ReviewAddNr = {
            fg = P.gray2,
            bg = U.blend(P.diff.add, green_dim, P.bg),
        },
        ReviewDelete = {
            bg = U.blend(P.diff.delete, 0.65, P.bg),
        },
        ReviewPanelLine = {
            bold = true,
        },
        ReviewPanelDir = {
            fg = P.gray2,
        },
        ReviewPanelNr = {
            fg = P.white0,
            bold = true,
        },
        ReviewChanged = {
            fg = P.yellow,
        },
        ReviewNew = {
            fg = P.green,
        },
        ReviewSignAdd = {
            fg = P.green,
            bg = U.blend(P.diff.add, green_dim, P.bg),
            bold = true,
        },
        ReviewSignLocal = {
            fg = P.yellow,
            bold = true,
        },
        ReviewSignDelete = {
            fg = P.red,
            bg = U.blend(P.diff.delete, 0.65, P.bg),
            bold = true,
        },
    },
})
