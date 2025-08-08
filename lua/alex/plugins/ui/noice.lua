local U = require("alex.utils.chars")

-- TODO: Will this slow things down?
local filter_notify = {
    "written",
    "fewer lines",
    "line less;",
    "Already at",
    "lines yanked",
    "more line",
    "change;",
    "E486",
    "No results",
    "Nothing currently selected",
    "changes;",
    "No information available",
    "has already been sent, please wait",
    "is not supported by any of the servers",
    "hover is not supported",
    "response of request method",
    "not found:",
    "No buffers found with",
    "no client attached",
    "E21",
    "E382",
    "E553",
    "Cursor position outside buffer",
    "telescope.builtin.lsp_definitions",
    "No signature help",
    "E42",
    "Format request failed",
    "Invalid window id: 1001", -- HACK: Plenary causes issues.  Look into this.
    "WARNING: vim.treesitter",
    "NotifyBackground",
    "No buffers were deleted:  bdelete #",
    "Can't find file",
    "server does not support",
    "No LSP Implementations found",
    "No more valid diagnostics",
    "warning: offset_encoding is required",
    "client.is_stopped",
    "No diagnostics found"
}

local function routes_config()
    local routes = {}
    for _, msg in ipairs(filter_notify) do
        local route = {
            filter = { find = msg },
            opts = { skip = true },
        }
        table.insert(routes, route)
    end
    return routes
end

local cmdline = {
    format = {
        cmdline = { title = "", icon = " " },
        lua = { title = "", icon = "󰢱 " },
        help = { title = "", icon = "󰋖 " },
        input = { title = "", icon = " " },
        filter = { title = "", icon = " " },
        search_up = { icon = "    " },
        search_down = { icon = "    " },
    },
}

local views = {
    cmdline_popup = {
        border = {
            style = U.border_chars_round,
            padding = { 0, 2 },
        },
        position = {
            row = "49%",
            col = "50%",
        },
    },
    hover = { border = { style = "rounded" } },
    float = { border = { style = "rounded" } },
    popup = { border = { style = "rounded" } },
}

local lsp = {
    override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
    },
    signature = { enabled = false, view = "popup" },
    progress = { enabled = true, view = "mini" },
}

local notify = {
    enabled = true,
    fps = 75,
    level = "ERROR",
}

local presets = {
    bottom_search = true, -- use a classic bottom cmdline for search
    command_palette = true, -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false, -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = true, -- add a border to hover docs and signature help
}

require("noice").setup({
    cmdline = cmdline,
    views = views,
    lsp = lsp,
    presets = presets,
    notify = notify,
    routes = routes_config(),
})

require("notify").setup({
    max_width = 70,
    min_width = 70,
})

require("alex.keymaps").noice()
