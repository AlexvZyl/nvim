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

local M = require("shared.plugin").config(defaults)

function M.set_highlights()
    -- Default links, so colorschemes can override them.
    local groups = {
        ReviewAdd = "DiffAdd",
        ReviewAddNr = "DiffAdd",
        ReviewDelete = "DiffDelete",
        ReviewDeleteNr = "DiffDelete",
        ReviewSignAdd = "Added",
        ReviewSignDelete = "Removed",
        ReviewSignLocalAdd = "ReviewSignAdd",
        ReviewSignLocalDelete = "ReviewSignDelete",
        ReviewLocalAdd = "ReviewAdd",
        ReviewLocalAddNr = "ReviewAddNr",
        ReviewLocalDelete = "ReviewDelete",
        ReviewLocalDeleteNr = "ReviewDeleteNr",
        ReviewPanelLine = "CursorLine",
        ReviewPanelDir = "Directory",
        ReviewPanelNr = "CursorLineNr",
        ReviewChanged = "Changed",
        ReviewNew = "Added",
        ReviewPanelAdded = "Added",
        ReviewPanelRemoved = "Removed",
        ReviewPanelDeleted = { strikethrough = true },
    }
    require("shared.plugin").link(groups)
    -- Background only, to put over syntax highlights.
    for _, group in ipairs({ "ReviewDelete", "ReviewLocalDelete" }) do
        vim.api.nvim_set_hl(0, group .. "Background", { bg = vim.api.nvim_get_hl(0, { name = group, link = false }).bg })
    end
    -- CursorLineNr on changed lines, with their background.
    local cursor = vim.api.nvim_get_hl(0, { name = "CursorLineNr", link = false })
    for _, group in ipairs({ "ReviewAddNr", "ReviewLocalAddNr", "ReviewDeleteNr", "ReviewLocalDeleteNr" }) do
        local bg = vim.api.nvim_get_hl(0, { name = group, link = false }).bg
        vim.api.nvim_set_hl(0, group:gsub("Nr$", "CursorNr"), vim.tbl_extend("force", cursor, { bg = bg }))
    end
end

return M
