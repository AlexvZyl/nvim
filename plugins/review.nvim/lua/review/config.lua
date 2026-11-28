local defaults = {
    -- Ref to review against by default.
    base = "dev",
    -- Panel width in columns, or below 1 a ratio of the editor's.
    width = 60,
    -- Directory levels to group files by.
    depth = 2,
    -- Below diagnostic signs at 10.
    sign_priority = 6,
    -- One or two cells each.
    signs = { committed = "│", uncommitted = "╎" },
    -- "since_review": changes since each file was reviewed. "all": changes since the merge base.
    view = "since_review",
    -- False to unmap.
    keymaps = {
        -- In the panel.
        open = "<CR>",
        mark_reviewed = "d",
        undo = "u",
        redo = "<C-r>",
        -- In buffers.
        next_hunk = "]h",
        prev_hunk = "[h",
    },
}

return require("shared.plugin").config(defaults)
