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
    -- What files show changed against: "since_review" for as reviewed, for the files changed since, "all" for the
    -- merge base.
    view = "since_review",
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

return require("shared.config").new(defaults)
