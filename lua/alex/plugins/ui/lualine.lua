local U = require("alex.utils")

local M = {}

----------------------------------------------------------------------------------------------------
--- Utils.

-- Custom mode names.
-- I want all of them to be the same length so that lualine stays constant.
local function fmt_mode(s)
    local mode_map = {
        ["COMMAND"] = "COMMND",
        ["V-BLOCK"] = "V-BLCK",
        ["TERMINAL"] = "TERMNL",
        ["V-REPLACE"] = "V-RPLC",
        ["O-PENDING"] = "0PNDNG",
    }
    return mode_map[s] or s
end

-- Theme dependant custom colors.
local text_hl
local icon_hl
local green
local red
if U.is_default() then
    local C = require("alex.native.default-theme").palette
    red = C.red
    green = C.green
    icon_hl = { fg = C.gray2 }
    text_hl = { fg = C.gray2 }
elseif U.is_nordic() then
    local C = require("nordic.colors")
    text_hl = { fg = C.gray3 }
    icon_hl = { fg = C.gray4 }
    green = C.green.base
    red = C.red.base
elseif U.is_tokyonight() then
    local C = require("tokyonight.colors.moon")
    text_hl = { fg = C.fg_gutter }
    icon_hl = { fg = C.dark3 }
    green = C.green1
    red = C.red1
end

local function get_virtual_text_color()
    local enabled = require("alex.native.lsp").virtual_diagnostics
    if enabled then
        return { fg = green }
    end
    return icon_hl
end

local function get_format_enabled_color()
    local enabled = require("alex.native.lsp").format_enabled
    if enabled then
        return { fg = green }
    end
    return icon_hl
end

local function get_recording_color()
    if U.is_recording() then
        return { fg = red }
    else
        return { fg = text_hl }
    end
end

local function diff_source()
    local gitsigns = vim.b.gitsigns_status_dict
    if gitsigns then
        return {
            added = gitsigns.added,
            modified = gitsigns.changed,
            removed = gitsigns.removed,
        }
    end
end

----------------------------------------------------------------------------------------------------
--- Defaults.

local default_z = {
    {
        "location",
        icon = { "", align = "left" },
        fmt = function(str)
            local fixed_width = 7
            return string.format("%" .. fixed_width .. "s", str)
        end,
    },
    {
        "progress",
        icon = { "", align = "left" },
        separator = { right = "", left = "" },
    },
}

local default_x = {
    {
        "diagnostics",
        sources = { "nvim_diagnostic" },
        symbols = {
            error = U.diagnostic_signs.error,
            warn = U.diagnostic_signs.warn,
            info = U.diagnostic_signs.info,
            hint = U.diagnostic_signs.hint,
            other = U.diagnostic_signs.other,
        },
        colored = true,
        padding = 2,
    },
    {
        U.current_buffer_lsp,
        padding = 1,
        color = text_hl,
        icon = { " ", color = icon_hl },
    },
    {
        function()
            return ""
        end,
        color = get_virtual_text_color,
        separator = { " ", "" },
    },
    {
        function()
            return "󰉼  "
        end,
        color = get_format_enabled_color,
        padding = 0,
    },
}

----------------------------------------------------------------------------------------------------
--- Custom.

local oil = {
    sections = {
        lualine_a = {
            {
                "mode",
                fmt = fmt_mode,
                icon = { "" },
                separator = { right = " ", left = "" },
            },
        },
        lualine_b = {},
        lualine_c = {
            {
                U.get_short_cwd,
                padding = 0,
                icon = { "   ", color = icon_hl },
                color = text_hl,
            },
        },
        lualine_x = default_x,
        lualine_y = {},
        lualine_z = default_z,
    },
    filetypes = { "oil" },
}

local telescope = {
    sections = {
        lualine_a = {
            {
                "mode",
                fmt = fmt_mode,
                icon = { "" },
                separator = { right = " ", left = "" },
            },
        },
        lualine_b = {},
        lualine_c = {
            {
                function()
                    return "Telescope"
                end,
                color = text_hl,
                icon = { "  ", color = icon_hl },
            },
        },
        lualine_x = default_x,
        lualine_y = {},
        lualine_z = default_z,
    },
    filetypes = { "TelescopePrompt" },
}

----------------------------------------------------------------------------------------------------
--- Setup.

require("lualine").setup({
    sections = {
        lualine_a = {
            {
                "mode",
                fmt = fmt_mode,
                icon = { "" },
                separator = { right = " ", left = "" },
            },
        },
        lualine_b = {},
        lualine_c = {
            {
                "branch",
                color = text_hl,
                icon = { " ", color = icon_hl },
                padding = 2,
            },
            {
                "diff",
                color = text_hl,
                source = diff_source,
                symbols = {
                    added = " ",
                    modified = " ",
                    removed = " ",
                },
                diff_color = {
                    added = icon_hl,
                    modified = icon_hl,
                    removed = icon_hl,
                },
                padding = 1,
            },
            {
                U.get_recording_state_icon,
                color = get_recording_color,
                padding = 1,
            },
        },
        lualine_x = default_x,
        lualine_y = {},
        lualine_z = default_z,
    },
    options = {
        disabled_filetypes = { "dashboard" },
        globalstatus = true,
        section_separators = { left = " ", right = " " },
        component_separators = { left = "", right = "" },
    },
    extensions = {
        telescope,
        oil,
    },
})

-- Ensure correct backgrond for lualine.
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    callback = function(_)
        require("lualine").setup({})
    end,
    pattern = { "*.*" },
    once = true,
})

-- Looks like this is no longer needed?
-- vim.defer_fn(function()
--     require("lualine").setup({})
-- end, 1)

if U.is_default() then
    require("alex.native.default-theme").setup_lualine()
end

function M.refresh_statusline()
    require("lualine").refresh({ statusline = true })
end

return M
