local M = {}

local defaults = {
    -- Ref to review against when `nvim diff` is given none.
    base = "dev",
    -- Width of the panel.
    width = 60,
    -- Directory levels the panel groups files by.
    depth = 2,
}

M.options = vim.deepcopy(defaults)

function M.set(opts)
    M.options = vim.tbl_extend("force", defaults, opts or {})
end

return M
