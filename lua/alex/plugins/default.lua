local P = require("default.palette")
local U = require("default.utils")

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
            bg = U.blend(P.diff.add, 0.3, P.bg),
        },
        ReviewDelete = {
            bg = U.blend(P.diff.delete, 0.6, P.bg),
        },
        ReviewQuickFixLine = {
            bold = true,
        },
        ReviewQuickFixNr = {
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
            bold = true,
        },
        ReviewSignLocal = {
            fg = P.yellow,
            bold = true,
        },
        ReviewSignDelete = {
            fg = P.red,
            bold = true,
        },
    },
})
