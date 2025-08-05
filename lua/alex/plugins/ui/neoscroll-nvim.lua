local M = {}

M.scroll_duration = 200

function M.init()
    local N = require("neoscroll")
    local keymap = {
        ["<C-u>"] = function()
            N.ctrl_u({ duration = M.scroll_duration })
        end,
        ["<C-d>"] = function()
            N.ctrl_d({ duration = M.scroll_duration })
        end,
        ["<C-b>"] = function()
            N.ctrl_b({ duration = M.scroll_duration })
        end,
        ["<C-f>"] = function()
            N.ctrl_f({ duration = M.scroll_duration })
        end,
        ["zt"] = function()
            N.zt({ half_win_duration = M.scroll_duration })
        end,
        ["zz"] = function()
            N.zz({ half_win_duration = M.scroll_duration })
        end,
        ["zb"] = function()
            N.zb({ half_win_duration = M.scroll_duration })
        end,
    }

    local modes = { "n", "v", "x" }
    for key, func in pairs(keymap) do
        vim.keymap.set(modes, key, func)
    end
end

return M
