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
    ReviewPanelDeleted = { strikethrough = true },
}

function M.set()
    for group, link in pairs(groups) do
        local hl = type(link) == "table" and link or { link = link }
        vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", hl, { default = true }))
    end
end

return M
