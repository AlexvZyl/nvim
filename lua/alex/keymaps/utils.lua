local M = {}

function M.save_file()
    if vim.api.nvim_buf_get_option(0, "readonly") then
        return
    end
    local buftype = vim.api.nvim_buf_get_option(0, "buftype")
    if buftype == "nofile" or buftype == "prompt" then
        return
    end
    if vim.api.nvim_buf_get_option(0, "modifiable") then
        vim.cmd("w!")
    end
end

M.DAP_UI_ENABLED = false
function M.dap_toggle_ui()
    require("dapui").toggle()
    M.DAP_UI_ENABLED = not M.DAP_UI_ENABLED
end

function M.dap_float_scope()
    if not M.DAP_UI_ENABLED then
        return
    end
    require("dapui").float_element("scopes")
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
    vim.cmd([[:bp | bdelete #]])
end

function M.toggle_oil()
    local U = require("alex.utils.neovim")
    if U.current_buffer_filetype() == "oil" then
        pcall(vim.api.nvim_command, "b#")
    else
        vim.cmd("Oil")
    end
end

return M
