local M = {}

-- Default links, so colorschemes can override them.
local groups = {
    StatuslineModeNormal = "PmenuSel",
    StatuslineModeInsert = "DiffAdd",
    StatuslineModeVisual = "Visual",
    StatuslineModeCommand = "IncSearch",
    StatuslineModePrompt = "WildMenu",
    StatuslineModeReplace = "DiffDelete",
    StatuslineModeTerminal = "Search",
    StatuslineModeUnknown = "ErrorMsg",
    StatuslineOn = "DiagnosticOk",
    StatuslineOff = "Comment",
    StatuslineDiagError = "DiagnosticError",
    StatuslineDiagWarn = "DiagnosticWarn",
    StatuslineDiagInfo = "DiagnosticInfo",
    StatuslineDiagHint = "DiagnosticHint",
}

function M.set()
    for group, link in pairs(groups) do
        vim.api.nvim_set_hl(0, group, { link = link, default = true })
    end
end

return M
