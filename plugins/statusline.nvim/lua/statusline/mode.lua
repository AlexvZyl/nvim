local M = {}

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

-- Label and highlight of the current mode.
function M.current()
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

return M
