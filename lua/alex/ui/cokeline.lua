local dark_bg
local inactive_bg
local bg
local fg
local inactive_fg
local title
local error
local warn

if vim.g.colors_name == 'nordic' then
    local P = require 'nordic.colors'
    local blend = require('nordic.utils').blend
    dark_bg = P.black0
    fg = P.fg
    bg = P.bg
    title = P.yellow.base
    error = P.error
    warn = P.warn
    inactive_fg = P.gray4
    inactive_bg = blend(P.bg, P.black0, 0.4)
elseif vim.g.colors_name == 'tokyonight' then
    local C = require 'tokyonight.colors'
    local U = require 'tokyonight.util'
    dark_bg = C.night.bg_dark
    fg = C.default.fg
    bg = C.night.bg
    warn = C.default.yellow
    error = C.default.red1
    title = C.default.yellow
    inactive_fg = C.default.fg_gutter
    inactive_bg = U.blend(C.night.bg, C.night.bg_dark, 0.4)
end

require('cokeline').setup {
    default_hl = {
        fg = function(buffer) return buffer.is_focused and fg or inactive_fg end,
        bg = function(buffer) return buffer.is_focused and bg or inactive_bg end,
    },
    sidebar = {
        filetype = 'NvimTree',
        components = {
            {
                text = ' 󰙅  File Explorer ',
                fg = title,
                bg = dark_bg,
                style = 'bold',
            },
        },
    },

    components = {
        {
            text = function(buffer)
                if buffer.index == 1 and require('nvim-tree.api').tree.is_visible() then return ' ' end
                return ''
            end,
            underline = function(buffer) return not buffer.is_focused end,
            bg = dark_bg,
            sp = dark_bg,
        },
        {
            text = function(buffer) return (buffer.index ~= 1) and '▎  ' or '   ' end,
            underline = function(buffer) return not buffer.is_focused end,
            fg = dark_bg,
            sp = dark_bg,
        },
        {
            text = function(buffer)
                if buffer.diagnostics.errors ~= 0 then return ' ' end
                if buffer.diagnostics.warnings ~= 0 then return ' ' end
                return buffer.devicon.icon
            end,
            fg = function(buffer)
                if buffer.diagnostics.errors ~= 0 then return error end
                if buffer.diagnostics.warnings ~= 0 then return warn end
                return buffer.is_focused and buffer.devicon.color
            end,
            underline = function(buffer) return not buffer.is_focused end,
            sp = dark_bg,
        },
        {
            text = ' ',
            underline = function(buffer) return not buffer.is_focused end,
            sp = dark_bg,
        },
        {
            text = function(buffer) return buffer.filename .. '  ' end,
            underline = function(buffer) return not buffer.is_focused end,
            sp = dark_bg,
        },
        {
            text = function(buffer)
                if buffer.is_readonly then return '' end
                if buffer.is_modified then return '●' end
                return ''
            end,
            delete_buffer_on_left_click = true,
            underline = function(buffer) return not buffer.is_focused end,
            sp = dark_bg,
        },
        {
            text = '   ',
            underline = function(buffer) return not buffer.is_focused end,
            sp = dark_bg,
        },
    },
}
