local M = {}

local defaults = {
    -- Filetypes left alone, like ones that set their own.
    exclude = {},
    -- By filetype or buftype: { icon = string, name = function, hide_modified = boolean }.
    bars = require("winbar.bars"),
}

M.options = vim.deepcopy(defaults)

function M.set(opts)
    M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
