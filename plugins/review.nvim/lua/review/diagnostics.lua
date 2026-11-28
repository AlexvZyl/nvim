-- Gives diagnostic signs and virtual text on changed lines the review background, which they do not inherit.
local M = {}

-- Neovim's own handlers, while replaced.
local original_handlers = {}
-- Combined groups already defined. Reset on colorscheme change.
local combined_groups = {}
-- By buffer and namespace, the marks restyled, to restore once their line is unchanged.
local restyled = {}

-- "<line group>_<diagnostic group>", so the diagnostic group can be recovered. Nil groups give the other.
local function combine(group, line_group, background_group)
    local diagnostic_group = group and group:match("^Review%a*Add_(.+)$") or group
    diagnostic_group = not (diagnostic_group and diagnostic_group:match("^Review%a*Add$")) and diagnostic_group or nil
    if not line_group or not diagnostic_group then
        return line_group or diagnostic_group
    end
    local name = line_group .. "_" .. diagnostic_group
    if not combined_groups[name] then
        local hl = vim.api.nvim_get_hl(0, { name = diagnostic_group, link = false })
        hl.bg = vim.api.nvim_get_hl(0, { name = background_group, link = false }).bg
        vim.api.nvim_set_hl(0, name, hl)
        combined_groups[name] = true
    end
    return name
end

-- Gives the mark its changed line's background, or its own back when line_group is nil.
local function restyle(bufnr, ns, mark, line_group)
    local id, row, col = mark[1], mark[2], mark[3]
    local details, needs_update = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, id, { details = true })[3], false
    if details.sign_hl_group then
        local group = combine(details.sign_hl_group, line_group, line_group and "ReviewSign" .. line_group:sub(7))
        needs_update, details.sign_hl_group = group ~= details.sign_hl_group, group
    end
    local had_gutter = details.virt_lines_leftcol
    for _, chunks in ipairs(details.virt_lines or { details.virt_text }) do
        -- Removes the padding and gutter added last time.
        local last = chunks[#chunks]
        if details.virt_lines and last and last[1]:match("^ +$") and (last[2] or ""):match("^Review%a*Add$") then
            table.remove(chunks)
            needs_update = true
        end
        if had_gutter and (chunks[2] and chunks[2][2] or ""):match("^ReviewSign") then
            table.remove(chunks, 1)
            table.remove(chunks, 1)
            needs_update = true
        end
        for _, chunk in ipairs(chunks) do
            if type(chunk[2]) ~= "table" then
                local group = combine(chunk[2], line_group, line_group)
                needs_update, chunk[2] = needs_update or group ~= chunk[2], group
            end
        end
        -- Virtual lines get the gutter and padding like changed lines.
        if details.virt_lines and line_group then
            table.insert(chunks, { string.rep(" ", vim.o.columns), line_group })
            local gutter = require("review.buffer").get(bufnr):gutter(line_group == "ReviewLocalAdd", "Add")
            table.insert(chunks, 1, gutter[2])
            table.insert(chunks, 1, gutter[1])
        end
    end
    if details.virt_lines then
        details.virt_lines_leftcol = line_group ~= nil
        needs_update = needs_update or details.virt_lines_leftcol ~= (had_gutter or false)
    end
    if needs_update then
        -- Not strict: edits can leave diagnostic marks past the last line.
        details.id, details.ns_id, details.strict = id, nil, false
        vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, details)
    end
end

function M.apply(bufnr)
    local changed_lines = require("review.render").changed_lines(bufnr)
    restyled[bufnr] = restyled[bufnr] or {}
    for _, diagnostic_ns in pairs(vim.diagnostic.get_namespaces()) do
        for _, ns_kind in ipairs({ "sign_ns", "virt_text_ns", "virt_lines_ns" }) do
            local ns = diagnostic_ns.user_data[ns_kind]
            if ns then
                local before, now = restyled[bufnr][ns] or {}, {}
                restyled[bufnr][ns] = now
                for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})) do
                    -- Only marks on changed lines, or restyled before.
                    local line_group = changed_lines[mark[2] + 1]
                    now[mark[1]] = line_group and true or nil
                    if line_group or before[mark[1]] then
                        restyle(bufnr, ns, mark, line_group)
                    end
                end
            end
        end
    end
end

function M.recolor()
    combined_groups = {}
end

-- Wraps the handlers, as diagnostics redraw by themselves.
function M.start()
    combined_groups, restyled = {}, {}
    for _, name in ipairs({ "signs", "virtual_text", "virtual_lines" }) do
        local handler = original_handlers[name] or vim.diagnostic.handlers[name]
        original_handlers[name] = handler
        vim.diagnostic.handlers[name] = {
            show = function(ns, bufnr, ...)
                handler.show(ns, bufnr, ...)
                M.apply(bufnr)
            end,
            hide = handler.hide,
        }
    end
end

function M.stop()
    if next(original_handlers) then
        for name, handler in pairs(original_handlers) do
            vim.diagnostic.handlers[name] = handler
        end
        original_handlers = {}
        vim.diagnostic.show()
    end
end

return M
