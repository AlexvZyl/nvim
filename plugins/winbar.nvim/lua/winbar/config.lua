local defaults = {
    -- Filetypes left alone, like ones that set their own.
    exclude = {},
    -- By filetype or buftype: { icon = string, name = function, hide_modified = boolean }.
    bars = require("winbar.bars"),
}

return require("shared.config").new(defaults)
