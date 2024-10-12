local M = {}

function M.save_file()
    if vim.api.nvim_buf_get_option(0, "readonly") then return end
    local buftype = vim.api.nvim_buf_get_option(0, "buftype")
    if buftype == "nofile" or buftype == "prompt" then return end
    if vim.api.nvim_buf_get_option(0, "modifiable") then vim.cmd("w!") end
end

M.DAP_UI_ENABLED = false
function M.dap_toggle_ui()
    require("dapui").toggle()
    M.DAP_UI_ENABLED = not M.DAP_UI_ENABLED
end

function M.dap_float_scope()
    if not M.DAP_UI_ENABLED then return end
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

M.virtual_diagnostics = false
function M.toggle_virtual_diagnostics()
    M.virtual_diagnostics = not M.virtual_diagnostics
    vim.diagnostic.config({ virtual_text = M.virtual_diagnostics })
    require("alex.utils").refresh_statusline()
end

function M.format_bufer()
    -- Remove trailing whitespace.
    local cursor_position = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_exec([[%s/\s\+$//e]], false)
    vim.cmd("noh")
    vim.api.nvim_win_set_cursor(0, cursor_position)

    -- Try to format the buffer using the attached lsp.
    local status, _ = pcall(vim.lsp.buf.format)
    if not status then vim.notify("Format failed") end
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
