local U = require("alex.utils.lua")

local default_settings = { noremap = true, silent = true }

-- TODO: This will break.
if not U.in_home_dir("Dev/Repos/lumen-labs-game") then
    return
end

local godot_buf = nil

vim.keymap.set("n", "<leader>g", function()
    if godot_buf == nil or not vim.api.nvim_buf_is_valid(godot_buf) then
        vim.cmd("terminal")
        godot_buf = vim.api.nvim_get_current_buf()
        vim.bo[godot_buf].filetype = "godot"
    else
        local win = vim.fn.bufwinid(godot_buf)
        if win ~= -1 then
            vim.api.nvim_set_current_win(win)
        else
            vim.api.nvim_win_set_buf(0, godot_buf)
        end
    end
    local chan = vim.b[godot_buf].terminal_job_id
    vim.api.nvim_chan_send(chan, "godot .\n")
end, default_settings)
