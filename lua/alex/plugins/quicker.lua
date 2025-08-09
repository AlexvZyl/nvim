local U = require("alex.utils.chars")

require("quicker").setup({
    type_icons = {
        E = U.diagnostic_signs.error,
        W = U.diagnostic_signs.warning,
        I = U.diagnostic_signs.info,
        N = U.diagnostic_signs.other,
        H = U.diagnostic_signs.hint,
    },
    borders = {
        vert = U.vertical_default .. " ",
    },
})
