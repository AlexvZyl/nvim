local config = require("statusline.config")
local highlights = require("statusline.highlights")
local modes = require("statusline.mode")
local parts = require("statusline.parts")

local M = {}

function M.render()
    local mode = modes.current()
    return table.concat({
        parts.segment(" " .. mode.label, mode),
        parts.lsp_clients(),
        parts.diagnostics(),
        "%=",
        " ",
        parts.toggles(),
        " ",
        parts.segment(" %4l:%-2c  %3p%%", mode),
    })
end

function M.refresh()
    vim.cmd.redrawstatus()
end

function M.setup(opts)
    config.set(opts)
    highlights.set()
    local group = vim.api.nvim_create_augroup("statusline", { clear = true })
    vim.api.nvim_create_autocmd("DiagnosticChanged", {
        group = group,
        callback = function(args)
            parts.diagnostics_changed(args.buf)
        end,
    })
    vim.o.laststatus = 3
    vim.o.statusline = "%{%v:lua.require'statusline'.render()%}"
end

return M
