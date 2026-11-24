local buffer = require("winbar.buffer")
local config = require("winbar.config")

local M = {}

function M.get_winbar()
    local prefix = "  "
    local modified = ""
    if not buffer.modifiable() then
        modified = " "
    elseif vim.bo.modified then
        modified = " ●"
    end

    local bars = config.options.bars
    local bar = bars[vim.bo.filetype] or bars[vim.bo.buftype]
    if bar then
        return prefix .. bar.icon .. " " .. bar.name() .. (bar.hide_modified and "" or modified)
    end

    local icon = buffer.icon() or ""
    local name = buffer.filename()
    if name == "" then
        name = "[No Name]"
        icon = " "
    end
    return prefix .. icon .. " " .. buffer.parent() .. name .. modified
end

function M.set_winbar()
    if vim.tbl_contains(config.options.exclude, vim.bo.filetype) then
        return
    end
    if vim.api.nvim_win_get_config(0).relative ~= "" then
        return
    end
    vim.opt_local.winbar = M.get_winbar()
end

function M.setup(opts)
    config.set(opts)
    local events = { "BufWritePost", "BufWinEnter", "BufFilePost", "WinEnter", "TermOpen", "BufReadPost" }
    -- Not available in all versions.
    if vim.fn.exists("##BufModifiedSet") == 1 then
        table.insert(events, "BufModifiedSet")
    end
    vim.api.nvim_create_autocmd(events, {
        group = vim.api.nvim_create_augroup("winbar", { clear = true }),
        callback = M.set_winbar,
    })
end

return M
