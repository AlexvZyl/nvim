local P = require("default.palette")

require("default").load({
    overrides = {
        Comment = {
            italic = true,
            fg = P.gray2
        },
        DiagnosticUnnecessary = {
            fg = P.white3,
            italic = false,
        }

    }
})
