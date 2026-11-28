-- Puts CursorLineNr back on the cursor line's number where a changed line's highlight hides it. One namespace per
-- window, as a buffer can show in several.
local config = require("review.config")
local draw = require("review.draw")

local M = {}

-- By window.
local marks = {}
-- From closed windows, for new ones.
local spare_namespaces = {}

-- The changed line's number group, nil when not changed or cursorline does not show numbers.
local function number_group(win, buf, row)
    local cursorlineopt = vim.wo[win].cursorlineopt
    if vim.wo[win].cursorline and (cursorlineopt:find("number") or cursorlineopt:find("both")) then
        local sign = vim.api.nvim_buf_get_extmarks(buf, draw.namespace, { row, 0 }, { row, 0 }, { details = true, overlap = true })[1]
        return sign and sign[4].number_hl_group
    end
end

function M.mark(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local row = vim.api.nvim_win_get_cursor(win)[1] - 1
    local group, tick, mark = number_group(win, buf, row), vim.b[buf].changedtick, marks[win]
    if mark and mark.buf == buf and mark.row == row and mark.group == group and mark.tick == tick then
        return
    end
    if mark and mark.id and vim.api.nvim_buf_is_valid(mark.buf) then
        vim.api.nvim_buf_del_extmark(mark.buf, mark.ns, mark.id)
    end
    local ns = mark and mark.ns
    if not ns then
        ns = table.remove(spare_namespaces) or vim.api.nvim_create_namespace("")
        vim.api.nvim__ns_set(ns, { wins = { win } })
    end
    marks[win] = {
        ns = ns,
        buf = buf,
        row = row,
        group = group,
        tick = tick,
        id = group and vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
            number_hl_group = group:gsub("Nr$", "CursorNr"),
            priority = config.options.sign_priority + 1,
        }),
    }
end

-- Clears marks of closed windows, keeping their namespaces.
function M.prune()
    for win, mark in pairs(marks) do
        if not vim.api.nvim_win_is_valid(win) then
            if vim.api.nvim_buf_is_valid(mark.buf) then
                vim.api.nvim_buf_clear_namespace(mark.buf, mark.ns, 0, -1)
            end
            table.insert(spare_namespaces, mark.ns)
            marks[win] = nil
        end
    end
end

function M.clear(buf)
    for _, mark in pairs(marks) do
        vim.api.nvim_buf_clear_namespace(buf, mark.ns, 0, -1)
    end
end

return M
