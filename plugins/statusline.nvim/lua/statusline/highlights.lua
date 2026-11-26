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
    require("shared.highlights").link(groups)
end

return M
