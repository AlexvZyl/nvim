local U = require("alex.utils")

-- Custom mode names.
-- I want all of them to be the same length so that lualine stays constant.
local function fmt_mode(s)
    local mode_map = {
        ["COMMAND"] = "COMMND",
        ["V-BLOCK"] = "VBLOCK",
        ["TERMINAL"] = "TERMNL",
        ["V-REPLACE"] = "VREPLC",
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
    local C = require("alex.native.themes.default").palette
    red = C.red
    green = C.green
    icon_hl = { fg = C.white3 }
    text_hl = { fg = C.white3 }
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
    local enabled = require("alex.keymaps.utils").virtual_diagnostics
    if enabled then return { fg = green } end
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

local tree = {
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
        lualine_x = {},
        lualine_y = {},
        lualine_z = {
            {
                "location",
                icon = { "", align = "left" },
            },
            {
                "progress",
                icon = { "", align = "left" },
                separator = { right = "", left = "" },
            },
        },
    },
    filetypes = { "NvimTree" },
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
                function() return "Telescope" end,
                color = text_hl,
                icon = { "  ", color = icon_hl },
            },
        },
        lualine_x = {},
        lualine_y = {},
        lualine_z = {
            {
                "location",
                icon = { "", align = "left" },
            },
            {
                "progress",
                icon = { "", align = "left" },
                separator = { right = "", left = "" },
            },
        },
    },
    filetypes = { "TelescopePrompt" },
}

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
                U.get_recording_icon,
                color = get_recording_color,
                padding = 0,
                separator = "",
            },
            {
                "branch",
                color = text_hl,
                icon = { " ", color = icon_hl },
                separator = "",
                padding = 0,
            },
            -- {
            --     U.get_git_compare,
            --     padding = { left = 1 },
            --     color = text_hl,
            --     separator = "",
            -- },
            {
                "diff",
                color = text_hl,
                icon = { "  ", color = text_hl },
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
                padding = 0,
            },
        },
        lualine_x = {
            {
                "diagnostics",
                sources = { "nvim_diagnostic" },
                symbols = {
                    error = " ",
                    warn = " ",
                    info = " ",
                    hint = "󱤅 ",
                    other = "󰠠 ",
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
                function() return " " end,
                color = get_virtual_text_color,
                padding = 1,
            },
        },
        lualine_y = {},
        lualine_z = {
            {
                "location",
                icon = { "", align = "left" },
            },
            {
                "progress",
                icon = { "", align = "left" },
                separator = { right = "", left = "" },
            },
        },
    },
    options = {
        disabled_filetypes = { "dashboard" },
        globalstatus = true,
        section_separators = { left = " ", right = " " },
        component_separators = { left = "", right = "" },
    },
    extensions = {
        telescope,
        ["nvim-tree"] = tree,
    },
})

-- Ensure correct backgrond for lualine.
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    callback = function(_) require("lualine").setup({}) end,
    pattern = { "*.*" },
    once = true,
})

require("alex.native.themes.default").setup_lualine()
