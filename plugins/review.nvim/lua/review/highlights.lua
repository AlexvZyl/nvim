local M = {}

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

function M.set()
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
