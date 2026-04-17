local U = require("alex.utils.neovim")

local M = {}

function M.save_file()
    if U.current_buffer_name() == "" then
        return
    end

    if U.current_buffer_modifiable() then
        vim.cmd("w!")
    end
end

function M.toggle_diffview()
    local view = require("diffview.lib").get_current_view()
    if view then
        vim.cmd("DiffviewClose")
    else
        vim.cmd("DiffviewOpen")
    end
end

function M.delete_buffer()
    vim.cmd([[:bdelete]])
end

function M.toggle_oil()
    if U.current_buffer_filetype() == "oil" then
        pcall(vim.api.nvim_command, "b#")
    else
        vim.cmd("Oil")
    end
end

return M
