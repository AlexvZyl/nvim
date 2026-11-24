-- Diagnostic signs and virtual text on changed lines get the review background, as neither the sign column nor
-- virtual text take it from the line highlight.
local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local handlers = {}
-- Groups already combined, made again once the colorscheme changes.
local combined = {}
-- By buffer and namespace, the marks given the review background, to put back once their line is not changed.
local restyled = {}

-- The group for a diagnostic group on the changed line, named <line group>_<group> so the diagnostic group is
-- known again once the line is not changed. Without a group, like padding, the line group itself.
local function combine(group, line, background)
    local base = group and group:match("^Review%a*Add_(.+)$") or group
    base = not (base and base:match("^Review%a*Add$")) and base or nil
    if not line or not base then
        return line or base
    end
    local name = line .. "_" .. base
    if not combined[name] then
        local hl = vim.api.nvim_get_hl(0, { name = base, link = false })
        hl.bg = vim.api.nvim_get_hl(0, { name = background, link = false }).bg
        vim.api.nvim_set_hl(0, name, hl)
        combined[name] = true
    end
    return name
end

function M.apply(buf)
    local changed = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
        if (mark[4].line_hl_group or ""):match("^Review%a*Add$") then
            for row = mark[2], mark[4].end_row or mark[2] do
                changed[row] = mark[4].line_hl_group
            end
        end
    end
    restyled[buf] = restyled[buf] or {}
    for _, ns in pairs(vim.diagnostic.get_namespaces()) do
        for _, kind in ipairs({ "sign_ns", "virt_text_ns", "virt_lines_ns" }) do
            local id = ns.user_data[kind]
            local before, after = restyled[buf][id] or {}, {}
            for _, mark in ipairs(id and vim.api.nvim_buf_get_extmarks(buf, id, 0, -1, {}) or {}) do
                local line, update = changed[mark[2]], false
                -- Only the marks on changed lines, or restyled before, need their details.
                local details = (line or before[mark[1]]) and vim.api.nvim_buf_get_extmark_by_id(buf, id, mark[1], { details = true })[3] or {}
                after[mark[1]] = line and true or nil
                if details.sign_hl_group then
                    local group = combine(details.sign_hl_group, line, line and "ReviewSign" .. line:sub(7))
                    update, details.sign_hl_group = group ~= details.sign_hl_group, group
                end
                local gutter = details.virt_lines_leftcol
                for _, chunks in ipairs(details.virt_lines or { details.virt_text }) do
                    -- Virtual lines get the gutter and are padded to the edge like the line highlight, which both
                    -- go again with it.
                    local last = chunks[#chunks]
                    if details.virt_lines and last and last[1]:match("^ +$") and (last[2] or ""):match("^Review%a*Add$") then
                        table.remove(chunks)
                        update = true
                    end
                    if gutter and (chunks[2] and chunks[2][2] or ""):match("^ReviewSign") then
                        table.remove(chunks, 1)
                        table.remove(chunks, 1)
                        update = true
                    end
                    for _, chunk in ipairs(chunks) do
                        if type(chunk[2]) ~= "table" then
                            local group = combine(chunk[2], line, line)
                            update, chunk[2] = update or group ~= chunk[2], group
                        end
                    end
                    if details.virt_lines and line then
                        table.insert(chunks, { string.rep(" ", vim.o.columns), line })
                        local columns = require("review.render").gutter(buf, line == "ReviewLocalAdd", "Add")
                        table.insert(chunks, 1, columns[2])
                        table.insert(chunks, 1, columns[1])
                    end
                end
                if details.virt_lines then
                    details.virt_lines_leftcol = line ~= nil
                    update = update or details.virt_lines_leftcol ~= (gutter or false)
                end
                if update then
                    details.id, details.ns_id = mark[1], nil
                    vim.api.nvim_buf_set_extmark(buf, id, mark[2], mark[3], details)
                end
            end
            if id then
                restyled[buf][id] = after
            end
        end
    end
end

-- Combined again with the new colors.
function M.recolor()
    combined = {}
end

-- Diagnostics redraw by themselves, like after leaving insert mode.
function M.start()
    combined, restyled = {}, {}
    for _, name in ipairs({ "signs", "virtual_text", "virtual_lines" }) do
        local handler = handlers[name] or vim.diagnostic.handlers[name]
        handlers[name] = handler
        vim.diagnostic.handlers[name] = {
            show = function(ns, buf, ...)
                handler.show(ns, buf, ...)
                M.apply(buf)
            end,
            hide = handler.hide,
        }
    end
end

function M.stop()
    if next(handlers) then
        for name, handler in pairs(handlers) do
            vim.diagnostic.handlers[name] = handler
        end
        handlers = {}
        vim.diagnostic.show()
    end
end

return M
