local M = {}

local options = {
    -- { enabled = function, icon = string }, shown on the right, highlighted by whether enabled.
    toggles = {},
}

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

local function mode(label, group)
    return { label = label, hl = "StatuslineMode" .. group }
end

local modes = {
    n = mode("NORMAL", "Normal"),
    i = mode("INSERT", "Insert"),
    v = mode("VISUAL", "Visual"),
    V = mode("V-LINE", "Visual"),
    [vim.keycode("<C-V>")] = mode("V-BLCK", "Visual"),
    s = mode("SELECT", "Visual"),
    S = mode("S-LINE", "Visual"),
    [vim.keycode("<C-S>")] = mode("S-BLCK", "Visual"),
    c = mode("COMMND", "Command"),
    r = mode("PROMPT", "Prompt"),
    R = mode("RPLACE", "Replace"),
    t = mode("TERMNL", "Terminal"),
    ["!"] = mode("SHELL ", "Terminal"),
}
local unknown = mode("??????", "Unknown")

local diagnostic_levels = {
    { vim.diagnostic.severity.ERROR, "StatuslineDiagError", "E" },
    { vim.diagnostic.severity.WARN, "StatuslineDiagWarn", "W" },
    { vim.diagnostic.severity.INFO, "StatuslineDiagInfo", "I" },
    { vim.diagnostic.severity.HINT, "StatuslineDiagHint", "H" },
}

-- Buffers that show the clients of the buffer before them, like prompts.
local keep_lsp_filetypes = { "noice", "TelescopePrompt", "" }

local function set_highlights()
    for group, link in pairs(groups) do
        vim.api.nvim_set_hl(0, group, { link = link, default = true })
    end
end

local function current_mode()
    local native = vim.api.nvim_get_mode().mode
    local m = modes[native] or modes[native:sub(1, 1)]
    if not m then
        vim.schedule(function()
            vim.notify_once("Unknown mode: " .. native, vim.log.levels.ERROR)
        end)
        m = unknown
    end
    return m
end

local function segment(content, m)
    return ("%%#%s# %s %%*"):format(m.hl, content)
end

local function icon(active, text)
    return "%#" .. (active and "StatuslineOn" or "StatuslineOff") .. "#" .. text .. "%*"
end

-- The linters of efm instead of efm itself.
local function client_names(client)
    if client.name ~= "efm" then
        return { client.name }
    end
    local sources = {}
    for _, tool in ipairs(vim.tbl_get(client.config, "settings", "languages", vim.bo.filetype) or {}) do
        if tool.lintSource then
            table.insert(sources, tool.lintSource)
        end
    end
    return #sources > 0 and sources or { client.name }
end

local previous_lsp = ""
local function lsp_clients()
    local names = {}
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
        vim.list_extend(names, client_names(client))
    end
    local result = table.concat(names, "•")
    if vim.tbl_contains(keep_lsp_filetypes, vim.bo.filetype) then
        result = previous_lsp
    else
        previous_lsp = result
    end
    return "  %#StatuslineOff# [" .. result .. "]%*"
end

local function diagnostics()
    local signs = vim.tbl_get(vim.diagnostic.config() or {}, "signs", "text") or {}
    local counts = vim.diagnostic.count(0)
    local parts = {}
    for _, level in ipairs(diagnostic_levels) do
        local n = counts[level[1]] or 0
        if n > 0 then
            table.insert(parts, ("%%#%s#%s %d%%*"):format(level[2], signs[level[1]] or level[3], n))
        end
    end
    if #parts == 0 then
        return ""
    end
    return "  " .. table.concat(parts, " ")
end

function M.render()
    local m = current_mode()
    local toggles = {}
    for i, toggle in ipairs(options.toggles) do
        toggles[i] = icon(toggle.enabled(), toggle.icon)
    end
    return table.concat({
        segment(" " .. m.label, m),
        lsp_clients(),
        diagnostics(),
        "%=",
        " ",
        table.concat(toggles),
        " ",
        segment(" %4l:%-2c  %3p%%", m),
    })
end

function M.refresh()
    vim.cmd.redrawstatus()
end

function M.setup(opts)
    options = vim.tbl_deep_extend("force", options, opts or {})
    set_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("statusline", { clear = true }),
        callback = set_highlights,
    })
    vim.o.laststatus = 3
    vim.o.statusline = "%{%v:lua.require'statusline'.render()%}"
end

return M
