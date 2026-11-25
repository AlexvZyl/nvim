local config = require("statusline.config")

local M = {}

-- vim.lsp and vim.diagnostic take a while to load, and until something else does there are no clients or
-- diagnostics to show, so they are left for it to load.
local function loaded(module)
    return package.loaded[module] ~= nil
end

-- By vim.diagnostic.severity, with the letter shown when the diagnostic signs have no text.
local diagnostic_levels = {
    { severity = 1, group = "StatuslineDiagError", letter = "E" },
    { severity = 2, group = "StatuslineDiagWarn", letter = "W" },
    { severity = 3, group = "StatuslineDiagInfo", letter = "I" },
    { severity = 4, group = "StatuslineDiagHint", letter = "H" },
}

-- Buffers that show the clients of the buffer before them, like prompts.
local keep_lsp_filetypes = { "noice", "TelescopePrompt", "" }

local function highlight(group, text)
    return "%#" .. group .. "#" .. text .. "%*"
end

-- Padded, in the colour of the mode.
function M.segment(content, mode)
    return highlight(mode.hl, " " .. content .. " ")
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
    for _, client in ipairs(loaded("vim.lsp") and vim.lsp.get_clients({ bufnr = 0 }) or {}) do
        vim.list_extend(names, client_names(client))
    end
    local result = table.concat(names, "•")
    if vim.tbl_contains(keep_lsp_filetypes, vim.bo.filetype) then
        result = previous_lsp
    else
        previous_lsp = result
    end
    return "  " .. highlight("StatuslineOff", " [" .. result .. "]")
end

-- By buffer, as counting goes through every diagnostic, which is slow to do on every redraw.
local counts = {}

-- Counted again once they changed.
function M.diagnostics_changed(buf)
    counts[buf] = nil
end

function M.diagnostics()
    if not loaded("vim.diagnostic") then
        return ""
    end
    local signs = vim.tbl_get(vim.diagnostic.config() or {}, "signs", "text") or {}
    local buf = vim.api.nvim_get_current_buf()
    counts[buf] = counts[buf] or vim.diagnostic.count(buf)
    local parts = {}
    for _, level in ipairs(diagnostic_levels) do
        local count = counts[buf][level.severity] or 0
        if count > 0 then
            table.insert(parts, highlight(level.group, (signs[level.severity] or level.letter) .. " " .. count))
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
        parts[i] = highlight(toggle.enabled() and "StatuslineOn" or "StatuslineOff", toggle.icon)
    end
    return table.concat(parts)
end

return M
