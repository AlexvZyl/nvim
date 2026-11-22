local M = {}
local TRANSPARENT = false

function M.set_highlights_table(table)
    for group, config in pairs(table) do
        vim.api.nvim_set_hl(0, group, config)
    end
end

function M.get_bg(color)
    return TRANSPARENT and "NONE" or color
end

-- Taken from folke/tokyonight
---@param c  string
function M.to_rgb(c)
    c = string.lower(c)
    return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

-- Taken from folke/tokyonight
---@param foreground string foreground color
---@param background string background color
---@param alpha number|string number between 0 and 1. 0 results in bg, 1 results in fg
function M.blend(foreground, alpha, background)
    alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha
    local bg = M.to_rgb(background)
    local fg = M.to_rgb(foreground)

    local blendChannel = function(i)
        local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
        return math.floor(math.min(math.max(0, ret), 255) + 0.5)
    end

    return string.format("#%02x%02x%02x", blendChannel(1), blendChannel(2), blendChannel(3))
end

function M.get_color_hex(name)
    local rgb = vim.api.nvim_get_color_by_name(name)
    return string.format("#%06x", rgb)
end

return M
