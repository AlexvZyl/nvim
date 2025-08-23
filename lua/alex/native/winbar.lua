local U = require("alex.utils.neovim")

vim.opt.winbar = nil

-- filetype/buftype
local winbar_type_exclude = {
    "dashboard",
}

-- [filetype/buftype]: bar
local custom_bars = {
    qf = {
        icon = "",
        name = function()
            return "QuickFix"
        end,
    },
    netrw = {
        icon = "",
        name = function()
            return "Netrw"
        end,
    },
    oil = {
        icon = " ",
        name = function()
            return string.gsub(vim.fn.expand("%"), "oil://", "")
        end,
    },
    checkhealth = {
        icon = "󰋠",
        name = function()
            return "Healthcheck"
        end,
    },
    man = {
        icon = "󰌽",
        name = function()
            local filename = U.current_buffer_filename()
            return "man/" .. string.gsub(filename, "man//", "")
        end,
    },
    terminal = {
        icon = "",
        name = function()
            return "Terminal"
        end,
    },
}

local function excludes()
    if vim.tbl_contains(winbar_type_exclude, vim.bo.filetype) then
        return true
    end
    return false
end

local M = {}

function M.get_winbar()
    local prefix = "  "
    local mod_icon = ""
    if U.current_buffer_modified() then
        mod_icon = " ●"
    elseif not U.current_buffer_modifiable() then
        mod_icon = " "
    end

    local filetype = U.current_buffer_filetype()
    local buftype = vim.bo.buftype
    local custom_bar = custom_bars[filetype] or custom_bars[buftype]
    if custom_bar ~= nil then
        return prefix
            .. custom_bar.icon
            .. " "
            .. custom_bar.name()
            .. mod_icon
    end

    local file_icon = U.current_buffer_icon()
    if file_icon == nil then
        file_icon = ""
    end

    local filename = U.current_buffer_filename()
    if filename == "" then
        filename = "[No Name]"
        file_icon = " "
    end

    return prefix .. file_icon .. " " .. U.current_buffer_parent() .. filename .. mod_icon
end

function M.set_winbar()
    if excludes() then
        return
    end
    if U.current_window_floating() then
        return
    end

    vim.opt_local.winbar = M.get_winbar()
end

vim.api.nvim_create_autocmd(
    { "BufModifiedSet", "BufWinEnter", "BufFilePost", "BufWritePost", "WinEnter", "TermOpen" },
    {
        callback = function()
            require("alex.native.winbar").set_winbar()
        end,
    }
)

return M
