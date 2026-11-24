-- Diagnostic signs on changed lines get the background of the review signs, as the sign column has no line
-- highlight of its own.
local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local handler

function M.apply(buf)
    local changed = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
        if (mark[4].line_hl_group or ""):match("^Review%a*Add$") then
            changed[mark[2]] = mark[4].line_hl_group
        end
    end
    for _, ns in pairs(vim.diagnostic.get_namespaces()) do
        local sign_ns = ns.user_data.sign_ns
        for _, mark in ipairs(sign_ns and vim.api.nvim_buf_get_extmarks(buf, sign_ns, 0, -1, { details = true }) or {}) do
            local details, line = mark[4], changed[mark[2]]
            -- Named <line group>_<sign group>, so the sign group is known again once the line is not changed.
            local sign = details.sign_hl_group and (details.sign_hl_group:match("_(.+)$") or details.sign_hl_group)
            local group = sign and line and line .. "_" .. sign or sign
            if group ~= sign then
                local hl = vim.api.nvim_get_hl(0, { name = sign, link = false })
                hl.bg = vim.api.nvim_get_hl(0, { name = "ReviewSign" .. line:sub(7), link = false }).bg
                vim.api.nvim_set_hl(0, group, hl)
            end
            if group ~= details.sign_hl_group then
                details.id, details.ns_id, details.sign_hl_group = mark[1], nil, group
                vim.api.nvim_buf_set_extmark(buf, sign_ns, mark[2], 0, details)
            end
        end
    end
end

-- Diagnostics redraw their signs by themselves, like after leaving insert mode.
function M.start()
    handler = handler or vim.diagnostic.handlers.signs
    vim.diagnostic.handlers.signs = {
        show = function(ns, buf, ...)
            handler.show(ns, buf, ...)
            M.apply(buf)
        end,
        hide = handler.hide,
    }
end

function M.stop()
    if handler then
        vim.diagnostic.handlers.signs, handler = handler, nil
        vim.diagnostic.show()
    end
end

return M
