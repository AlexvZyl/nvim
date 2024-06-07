local u = require("alex.utils")

local function routes_config()
    -- TODO(alex): Will this slow things down?
    local msgs = {
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
        "No diagnostics found",
    }

    local routes = {}
    for _, msg in ipairs(msgs) do
        local route = {
            filter = { find = msg },
            opts = { skip = true },
        }
        table.insert(routes, route)
    end
    return routes
end

require("noice").setup({
    cmdline = {
        format = {
            cmdline = { title = "", icon = " " },
            lua = { title = "", icon = "󰢱 " },
            help = { title = "", icon = "󰋖 " },
            input = { title = "", icon = " " },
            filter = { title = "", icon = " " },
            search_up = { icon = "    " },
            search_down = { icon = "    " },
        },
    },
    views = {
        cmdline_popup = {
            border = {
                style = u.border_chars_round,
                padding = { 0, 2 },
            },
            position = {
                row = "49%",
                col = "50%",
            },
        },
    },
    lsp = {
        override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
        },
        signature = { enabled = false, view = "virtualtext" },
    },
    presets = {
        bottom_search = true, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = false, -- add a border to hover docs and signature help
    },
    notify = {
        fps = 75,
        max_width = 75,
        level = "ERROR",
    },
    routes = routes_config(),
})
