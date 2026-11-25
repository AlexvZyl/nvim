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
    for group, link in pairs(groups) do
        local hl = type(link) == "table" and link or { link = link }
        vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", hl, { default = true }))
    end
    -- Only the background of deleted lines, put over the syntax of their text, which can have its own, like markdown
    -- code blocks.
    for _, group in ipairs({ "ReviewDelete", "ReviewLocalDelete" }) do
        vim.api.nvim_set_hl(0, group .. "Background", { bg = vim.api.nvim_get_hl(0, { name = group, link = false }).bg })
    end
end

return M
