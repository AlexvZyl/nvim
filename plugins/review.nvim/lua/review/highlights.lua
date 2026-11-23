local M = {}

-- Default links, so colorschemes can override them.
local groups = {
    ReviewAdd = "DiffAdd",
    ReviewAddNr = "DiffAdd",
    ReviewDelete = "DiffDelete",
    ReviewSignAdd = "Added",
    ReviewSignDelete = "Removed",
    ReviewSignLocalAdd = "ReviewSignAdd",
    ReviewSignLocalDelete = "ReviewSignDelete",
    ReviewLocalAdd = "ReviewAdd",
    ReviewLocalAddNr = "ReviewAddNr",
    ReviewLocalDelete = "ReviewDelete",
    ReviewPanelLine = "CursorLine",
    ReviewPanelDir = "Directory",
    ReviewPanelNr = "CursorLineNr",
    ReviewChanged = "Changed",
    ReviewNew = "Added",
}

function M.set()
    for group, link in pairs(groups) do
        vim.api.nvim_set_hl(0, group, { link = link, default = true })
    end
end

return M
