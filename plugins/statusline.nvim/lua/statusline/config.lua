local M = {}

local defaults = {
    -- { enabled = function, icon = string }, shown on the right, highlighted by whether enabled.
    toggles = {},
}

M.options = vim.deepcopy(defaults)

function M.set(opts)
    M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
