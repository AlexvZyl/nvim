local config = require("statusline.config")
local highlights = require("statusline.highlights")
local mode = require("statusline.mode")
local parts = require("statusline.parts")

local M = {}

function M.render()
    local m = mode.current()
    return table.concat({
        parts.segment(" " .. m.label, m),
        parts.lsp_clients(),
        parts.diagnostics(),
        "%=",
        " ",
        parts.toggles(),
        " ",
        parts.segment(" %4l:%-2c  %3p%%", m),
    })
end

function M.refresh()
    vim.cmd.redrawstatus()
end

function M.setup(opts)
    config.set(opts)
    highlights.set()
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("statusline", { clear = true }),
        callback = highlights.set,
    })
    vim.o.laststatus = 3
    vim.o.statusline = "%{%v:lua.require'statusline'.render()%}"
end

return M
