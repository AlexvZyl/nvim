local N = require("neoscroll")

local M = {}
M.duration = 200

local keymap = {
    ["<C-u>"] = function()
        N.ctrl_u({ duration = M.duration })
    end,
    ["<C-d>"] = function()
        N.ctrl_d({ duration = M.duration })
    end,
    ["<C-b>"] = function()
        N.ctrl_b({ duration = M.duration })
    end,
    ["<C-f>"] = function()
        N.ctrl_f({ duration = M.duration })
    end,
    ["zt"] = function()
        N.zt({ half_win_duration = M.duration })
    end,
    ["zz"] = function()
        N.zz({ half_win_duration = M.duration })
    end,
    ["zb"] = function()
        N.zb({ half_win_duration = M.duration })
    end,
}

local modes = { "n", "v", "x" }
for key, func in pairs(keymap) do
    vim.keymap.set(modes, key, func)
end

return M
