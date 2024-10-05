local M = {}

function M.current_buffer_filetype() return vim.bo.filetype end

function M.current_buffer_type() return vim.bo.buftype end

function M.current_buffer_modified() return vim.bo.modified end

function M.current_window_floating() return vim.api.nvim_win_get_config(0).relative ~= "" end

function M.current_buffer_dir() return vim.api.nvim_buf_get_name(0):match("(.*" .. "/" .. ")") end

function M.current_window() return vim.api.nvim_get_current_win() end

function M.current_window_hl(hl)
    local win = M.current_window()
    vim.api.nvim_win_set_option(win, "winhl", hl)
end

function M.current_buffer_modifiable()
    local buftype = M.current_buffer_type()
    if buftype == "nofile" or buftype == "prompt" or buftype == "help" then return false end
    return true
end

function M.set_highlight(hl, config) vim.api.nvim_set_hl(0, hl, config) end

function M.set_highlights_table(table)
    for group, config in pairs(table) do
        vim.api.nvim_set_hl(0, group, config)
    end
end

function M.current_buffer_filename()
    local bufname = vim.api.nvim_buf_get_name(0)
    return bufname ~= "" and vim.fn.fnamemodify(bufname, ":t") or ""
end

local function get_short_cwd() return vim.fn.fnamemodify(vim.fn.getcwd(), ":~") end

function M.current_buffer_icon()
    local c = M.current_buffer_filetype()
    if c == "help" then return "󰞋" end
    return require("nvim-web-devicons").get_icon_by_filetype(c)
end

function M.current_buffer_parent()
    local current_buffer = vim.api.nvim_get_current_buf()
    local current_file = vim.api.nvim_buf_get_name(current_buffer)
    local parent = vim.fn.fnamemodify(current_file, ":h:t")
    if parent == "." then return "" end
    return parent .. "/"
end

function M.current_buffer_full_file() return vim.fn.expand("%") end

function M.current_buffer_lsp()
    local buf_ft = M.current_buffer_filetype()
    local clients = vim.lsp.get_clients()
    if next(clients) == nil then return "" end
    local current_clients = ""

    for _, client in ipairs(clients) do
        local filetypes = client.config.filetypes
        if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
            current_clients = current_clients .. client.name .. " "
        end
    end

    return current_clients
end

function M.is_recording() return vim.fn.reg_recording() ~= "" end

function M.link_hl(target, link) vim.api.nvim_set_hl(0, target, { link = link }) end

function M.is_nordic() return vim.g.colors_name == "nordic" end

function M.is_tokyonight() return vim.g.colors_name == "tokyonight" end

function M.is_default() return vim.g.colors_name == "default" or vim.g.colors_name == nil end

function M.hl_group_rgb(group) return vim.api.nvim_get_hl(0, { name = group, link = false }) end

function M.refresh_statusline() require("lualine").refresh({ statusline = true }) end

function M.get_hl_group(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end

return M
