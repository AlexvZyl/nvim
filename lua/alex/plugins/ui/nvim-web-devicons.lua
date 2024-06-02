local icons = require("nvim-web-devicons")

local go_icon = {
    icon = "",
    color = "#519aba",
    name = "go",
}

icons.setup({
    strict = true,
    override_by_filename = {
        ["go.mod"] = go_icon,
        ["go.sum"] = go_icon,
    },
})
