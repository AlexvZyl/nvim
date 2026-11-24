local M = {}

function M.current_buffer_filetype()
    return vim.bo.filetype
end

function M.current_buffer_modified()
    return vim.bo.modified
end

function M.current_buffer_name()
    return vim.api.nvim_buf_get_name(0)
end

function M.merge_highlights_table(table)
    for group, new_config in pairs(table) do
        local existing_config = vim.api.nvim_get_hl(0, { name = group })
        if not next(existing_config) then
            existing_config = {}
        end
        local merged_config = vim.tbl_extend("force", existing_config, new_config)
        vim.api.nvim_set_hl(0, group, merged_config)
    end
end

function M.current_buffer_file_relative()
    return vim.fn.expand("%")
end

function M.open_float(lines, filetype)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = filetype or ""
    vim.bo[buf].modifiable = false
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
    })
    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end
    local buf_opts = { buffer = buf, silent = true, nowait = true }
    vim.keymap.set("n", "q", close, buf_opts)
end

return M
