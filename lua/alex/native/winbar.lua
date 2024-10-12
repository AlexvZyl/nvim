local U = require("alex.utils.neovim")

vim.opt.winbar = nil

local winbar_filetype_exclude = {
    "dashboard",
}

-- filetype: bar
local custom_bars = {
    qf = { icon = "", name = function() return "QuickFix" end },
    netrw = { icon = "", name = function() return "Netrw" end },
    oil = {
        icon = " ",
        name = function() return string.gsub(vim.fn.expand("%"), "oil://", "") end,
    },
    checkhealth = {
        icon = " ",
        name = function() return "Checkhealth" end,
    },
}

local excludes = function()
    if vim.tbl_contains(winbar_filetype_exclude, vim.bo.filetype) then return true end
    return false
end

local M = {}

function M.get_winbar()
    local prefix = "  "
    local mod_icon = ""
    if U.current_buffer_modified() then
        mod_icon = " ●"
    elseif not U.current_buffer_modifiable() then
        mod_icon = "  "
    end

    local filetype = U.current_buffer_filetype()
    if custom_bars[filetype] ~= nil then
        return prefix
            .. custom_bars[filetype].icon
            .. " "
            .. custom_bars[filetype].name()
            .. mod_icon
    end

    local file_icon = U.current_buffer_icon()
    if file_icon == nil then file_icon = "" end

    local filename = U.current_buffer_filename()
    if filename == "" then
        filename = "[No Name]"
        file_icon = " "
    end

    return prefix .. file_icon .. " " .. U.current_buffer_parent() .. filename .. mod_icon
end

function M.set_winbar(force)
    if not force then
        if excludes() then return end
        if U.current_window_floating() then return end
    end

    vim.opt_local.winbar = M.get_winbar()
end

vim.api.nvim_create_autocmd(
    { "BufModifiedSet", "BufWinEnter", "BufFilePost", "BufWritePost", "WinEnter" },
    {
        callback = function() require("alex.native.winbar").set_winbar() end,
    }
)

return M
