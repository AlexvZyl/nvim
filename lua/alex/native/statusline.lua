local C = require("default.palette")
local U = require("alex.utils")
local lsp_state = require("alex.native.lsp")
local nnp = require("alex.plugins.no-neck-pain")

-- TODO: Vibe coded, revisit.

local M = {}

local mode_map = {}
local fallback_mode

local diag_levels = {
    { vim.diagnostic.severity.ERROR, "StlDiagError", "error" },
    { vim.diagnostic.severity.WARN, "StlDiagWarn", "warn" },
    { vim.diagnostic.severity.INFO, "StlDiagInfo", "info" },
    { vim.diagnostic.severity.HINT, "StlDiagHint", "hint" },
}

local function hl_suffix(color)
    return (color:gsub("#", ""))
end

local function make_mode(label, color)
    local suffix = hl_suffix(color)
    return {
        label = label,
        color = color,
        mode_hl = "StlMode_" .. suffix,
    }
end

local function build_mode_map()
    mode_map = {
        n = make_mode("NORMAL", C.blue),
        i = make_mode("INSERT", C.green),
        v = make_mode("VISUAL", C.red),
        V = make_mode("V-LINE", C.red),
        ["\22"] = make_mode("V-BLCK", C.red),
        s = make_mode("SELECT", C.red),
        S = make_mode("S-LINE", C.red),
        ["\19"] = make_mode("S-BLCK", C.red),
        c = make_mode("COMMND", C.orange),
        r = make_mode("PROMPT", C.magenta),
        R = make_mode("RPLACE", C.red),
        t = make_mode("TERMNL", C.yellow),
        ["!"] = make_mode("SHELL ", C.yellow),
    }
    fallback_mode = make_mode("??????", C.green)
end

local function apply_highlights()
    local hls = {
        StlOn = { fg = C.green },
        StlOff = { fg = C.gray2 },
        StlDiagError = { fg = C.red },
        StlDiagWarn = { fg = C.yellow },
        StlDiagInfo = { fg = C.blue },
        StlDiagHint = { fg = C.green },
        StlRecording = { fg = C.red },
    }
    local seen = {}
    for _, info in pairs(mode_map) do
        if not seen[info.color] then
            seen[info.color] = true
            hls[info.mode_hl] = { fg = C.bg_dark, bg = info.color, bold = true }
        end
    end
    for name, opts in pairs(hls) do
        vim.api.nvim_set_hl(0, name, opts)
    end
end

local function current_mode()
    return mode_map[vim.api.nvim_get_mode().mode] or fallback_mode
end

local function segment(content, info)
    return ("%%#%s# %s %%*"):format(info.mode_hl, content)
end

local function icon(active, text)
    return "%#" .. (active and "StlOn" or "StlOff") .. "#" .. text .. "%*"
end

local function lsp_clients()
    local names = U.current_buffer_lsp()
    if names == "" then
        return ""
    end
    return "  %#StlOff#󰒍 " .. names .. "%*"
end

local function recording()
    if not U.is_recording() then
        return ""
    end
    return ("%%#StlRecording#%s%s%%* "):format(U.kind_icons.Recording, vim.fn.reg_recording())
end

local function diagnostics()
    local signs = U.diagnostic_signs
    local counts = vim.diagnostic.count(0)
    local parts = {}
    for _, l in ipairs(diag_levels) do
        local n = counts[l[1]] or 0
        if n > 0 then
            parts[#parts + 1] = ("%%#%s#%s%d%%*"):format(l[2], signs[l[3]], n)
        end
    end
    if #parts == 0 then
        return ""
    end
    return "  " .. table.concat(parts, " ")
end

function M.render()
    local m = current_mode()
    return segment(" " .. m.label, m)
        .. lsp_clients()
        .. diagnostics()
        .. "%="
        .. recording()
        .. " "
        .. icon(lsp_state.virtual_diagnostics, " ")
        .. icon(nnp.enabled, " ")
        .. icon(lsp_state.format_enabled, "󰉼 ")
        .. " "
        .. segment(" %4l:%-2c  %3p%%", m)
end

function M.refresh()
    vim.cmd.redrawstatus()
end

function M.setup()
    build_mode_map()
    apply_highlights()

    vim.o.laststatus = 3
    vim.o.statusline = "%{%v:lua.require'alex.native.statusline'.render()%}"

    local group = vim.api.nvim_create_augroup("AlexStatusline", { clear = true })
    vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
        group = group,
        callback = M.refresh,
    })
end

M.setup()

return M
