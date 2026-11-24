-- The current buffer.
local M = {}

function M.filename()
    local name = vim.api.nvim_buf_get_name(0)
    return name ~= "" and vim.fn.fnamemodify(name, ":t") or ""
end

function M.parent()
    local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h:t")
    return dir == "." and "" or dir .. "/"
end

function M.icon()
    if vim.bo.filetype == "help" then
        return "󰞋"
    end
    return require("nvim-web-devicons").get_icon_by_filetype(vim.bo.filetype)
end

function M.modifiable()
    return not vim.tbl_contains({ "nofile", "prompt", "help" }, vim.bo.buftype) and not vim.bo.readonly
end

return M
