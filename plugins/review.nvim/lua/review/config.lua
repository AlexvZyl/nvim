local M = {}

local defaults = {
    -- Ref to review against when `nvim diff` is given none.
    base = "dev",
    -- Width of the panel.
    width = 60,
    -- Directory levels the panel groups files by.
    depth = 2,
    -- False leaves a key unmapped.
    keymaps = {
        -- In the panel.
        open = "<CR>",
        review = "d",
        undo = "u",
        redo = "<C-r>",
        -- In reviewed files.
        next_hunk = "]h",
        prev_hunk = "[h",
    },
}

M.options = vim.deepcopy(defaults)

function M.set(opts)
    M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
