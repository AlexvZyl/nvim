local config = require("statusline.config")

local M = {}

local diagnostic_levels = {
    { vim.diagnostic.severity.ERROR, "StatuslineDiagError", "E" },
    { vim.diagnostic.severity.WARN, "StatuslineDiagWarn", "W" },
    { vim.diagnostic.severity.INFO, "StatuslineDiagInfo", "I" },
    { vim.diagnostic.severity.HINT, "StatuslineDiagHint", "H" },
}

-- Buffers that show the clients of the buffer before them, like prompts.
local keep_lsp_filetypes = { "noice", "TelescopePrompt", "" }

function M.segment(content, m)
    return ("%%#%s# %s %%*"):format(m.hl, content)
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
function M.lsp_clients()
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
    return "  %#StatuslineOff# [" .. result .. "]%*"
end

function M.diagnostics()
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

function M.toggles()
    local parts = {}
    for i, toggle in ipairs(config.options.toggles) do
        parts[i] = "%#" .. (toggle.enabled() and "StatuslineOn" or "StatuslineOff") .. "#" .. toggle.icon .. "%*"
    end
    return table.concat(parts)
end

return M
