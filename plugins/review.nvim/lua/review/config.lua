local M = {}

local defaults = {
    -- Ref to review against when `nvim diff` is given none.
    base = "dev",
    -- Width of the panel, in columns, or below 1 as a ratio of the editor's, kept as it resizes.
    width = 60,
    -- Directory levels the panel groups files by.
    depth = 2,
    -- Of the signs, under the diagnostic signs at 10.
    sign_priority = 6,
    -- Of committed and uncommitted changes, one or two cells.
    signs = { committed = "│", uncommitted = "╎" },
    -- What files show changed against: "all" for the merge base, "since_review" for as reviewed, for the files
    -- changed since.
    view = "all",
    -- False leaves a key unmapped.
    keymaps = {
        -- In the panel.
        open = "<CR>",
        mark_reviewed = "d",
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
