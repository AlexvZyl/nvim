-- Diagnostic signs on changed lines get the background of the review signs, as the sign column has no line
-- highlight of its own.
local M = {}

local namespace = vim.api.nvim_create_namespace("review")
-- Background of the sign column by the line highlight of a changed line.
local backgrounds = {
    ReviewAdd = "ReviewSignAdd",
    ReviewLocalAdd = "ReviewSignLocalAdd",
}
-- Combined group by line highlight and sign group, and the sign group of each combined one.
local combined, original = {}, {}
local handler

local function define(name, sign, line)
    local hl = vim.api.nvim_get_hl(0, { name = sign, link = false })
    hl.bg = vim.api.nvim_get_hl(0, { name = backgrounds[line], link = false }).bg
    vim.api.nvim_set_hl(0, name, hl)
end

local function group(sign, line)
    combined[line] = combined[line] or {}
    local name = combined[line][sign]
    if not name then
        name = "Review" .. line:gsub("^Review", "") .. sign
        combined[line][sign] = name
        original[name] = sign
        define(name, sign, line)
    end
    return name
end

-- Again once the colorscheme changed.
function M.colors()
    for line, signs in pairs(combined) do
        for sign, name in pairs(signs) do
            define(name, sign, line)
        end
    end
end

local function sign_namespaces()
    local namespaces = {}
    for _, ns in pairs(vim.diagnostic.get_namespaces()) do
        if ns.user_data and ns.user_data.sign_ns then
            table.insert(namespaces, ns.user_data.sign_ns)
        end
    end
    return namespaces
end

-- Recolors the diagnostic signs of the buffer by the changed lines they are on, and back once they are not.
function M.apply(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local changed = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
        if backgrounds[mark[4].line_hl_group] then
            changed[mark[2]] = mark[4].line_hl_group
        end
    end
    for _, ns in ipairs(sign_namespaces()) do
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true, type = "sign" })) do
            local id, row, details = mark[1], mark[2], mark[4]
            local sign = original[details.sign_hl_group] or details.sign_hl_group
            local want = sign and changed[row] and group(sign, changed[row]) or sign
            if want ~= details.sign_hl_group then
                vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
                    id = id,
                    sign_text = details.sign_text,
                    sign_hl_group = want,
                    number_hl_group = details.number_hl_group,
                    line_hl_group = details.line_hl_group,
                    cursorline_hl_group = details.cursorline_hl_group,
                    priority = details.priority,
                    right_gravity = details.right_gravity,
                    invalidate = details.invalidate,
                    undo_restore = details.undo_restore,
                })
            end
        end
    end
end

-- Diagnostics redraw their signs by themselves, like after leaving insert mode.
function M.start()
    if handler then
        return
    end
    handler = vim.diagnostic.handlers.signs
    vim.diagnostic.handlers.signs = {
        show = function(ns, buf, ...)
            handler.show(ns, buf, ...)
            M.apply(buf)
        end,
        hide = handler.hide,
    }
end

function M.stop()
    if not handler then
        return
    end
    vim.diagnostic.handlers.signs = handler
    handler = nil
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            M.apply(buf)
        end
    end
end

return M
