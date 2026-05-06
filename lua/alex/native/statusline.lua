local C = require("default.palette")

local M = {}

vim.api.nvim_set_hl(0, "StlOn", { fg = C.green })
vim.api.nvim_set_hl(0, "StlOff", { fg = C.gray2 })
vim.api.nvim_set_hl(0, "StlDiagError", { fg = C.red })
vim.api.nvim_set_hl(0, "StlDiagWarn", { fg = C.yellow })
vim.api.nvim_set_hl(0, "StlDiagInfo", { fg = C.blue })
vim.api.nvim_set_hl(0, "StlDiagHint", { fg = C.green })
vim.api.nvim_set_hl(0, "StlRecording", { fg = C.red })

local mode_map = {
    ["n"] = { "NORMAL", C.blue },
    ["i"] = { "INSERT", C.green },
    ["v"] = { "VISUAL", C.red },
    ["V"] = { "V-LINE", C.red },
    ["\22"] = { "V-BLCK", C.red },
    ["s"] = { "SELECT", C.red },
    ["S"] = { "S-LINE", C.red },
    ["\19"] = { "S-BLCK", C.red },
    ["c"] = { "COMMND", C.orange },
    ["r"] = { "PROMPT", C.magenta },
    ["R"] = { "RPLACE", C.red },
    ["t"] = { "TERMNL", C.yellow },
    ["!"] = { "SHELL", C.yellow },
}

local function hl_name(prefix, color)
    return prefix .. color:gsub("#", "")
end

for _, info in pairs(mode_map) do
    local color = info[2]
    vim.api.nvim_set_hl(0, hl_name("StlMode_", color), { fg = C.bg_dark, bg = color, bold = true })
    vim.api.nvim_set_hl(0, hl_name("StlModeSep_", color), { fg = color, bg = C.bg_dark })
end

local function segment(content, color)
    color = color or C.green
    local mode_hl = hl_name("StlMode_", color)
    local sep_hl = hl_name("StlModeSep_", color)
    return ("%%#%s#\u{e0b6}%%#%s# %s %%#%s#\u{e0b4}%%*"):format(sep_hl, mode_hl, content, sep_hl)
end

local function mode()
    local info = mode_map[vim.api.nvim_get_mode().mode] or { "??????", C.green }
    return segment(" " .. info[1], info[2])
end

local function pos()
    local info = mode_map[vim.api.nvim_get_mode().mode] or { "??????", C.green }
    return segment(" %3l:%-2c  %3p%%", info[2])
end

local function icon(active, text)
    return "%#" .. (active and "StlOn" or "StlOff") .. "#" .. text .. "%*"
end

local function lsp_clients()
    local names = require("alex.utils").current_buffer_lsp()
    if names == "" then
        return ""
    end
    return "  %#StlOff#󰒍 " .. names .. "%*"
end

local function recording()
    local U = require("alex.utils")
    if not U.is_recording() then
        return ""
    end
    return ("%%#StlRecording#%s%s%%* "):format(U.kind_icons.Recording, vim.fn.reg_recording())
end

local function diagnostics()
    local signs = require("alex.utils").diagnostic_signs
    local levels = {
        { vim.diagnostic.severity.ERROR, "StlDiagError", signs.error },
        { vim.diagnostic.severity.WARN,  "StlDiagWarn",  signs.warn },
        { vim.diagnostic.severity.INFO,  "StlDiagInfo",  signs.info },
        { vim.diagnostic.severity.HINT,  "StlDiagHint",  signs.hint },
    }
    local parts = {}
    for _, l in ipairs(levels) do
        local n = #vim.diagnostic.get(0, { severity = l[1] })
        if n > 0 then
            table.insert(parts, ("%%#%s#%s%d%%*"):format(l[2], l[3], n))
        end
    end
    if #parts == 0 then
        return ""
    end
    return "  " .. table.concat(parts, " ")
end

function _G.alex_statusline()
    local lsp = require("alex.native.lsp")
    local nnp = require("alex.plugins.no-neck-pain")
    return mode()
        .. lsp_clients()
        .. diagnostics()
        .. "%="
        .. recording()
        .. " "
        .. icon(lsp.virtual_diagnostics, " ")
        .. icon(nnp.enabled, " ")
        .. icon(lsp.format_enabled, "󰉼 ")
        .. " "
        .. pos()
end

vim.o.laststatus = 3
vim.o.statusline = "%{%v:lua.alex_statusline()%}"

vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
    group = vim.api.nvim_create_augroup("AlexStatuslineRecording", { clear = true }),
    callback = function()
        vim.cmd.redrawstatus()
    end,
})

function M.refresh()
    vim.cmd.redrawstatus()
end

return M
