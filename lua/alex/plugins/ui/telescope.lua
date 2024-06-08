local ts = require("telescope")
local U = require("alex.utils")

local prompt_chars = { "▔", "▕", " ", "▏", "🭽", "🭾", "▕", "▏" }
local vert_preview_chars =
    { " ", "▕", "▁", "▏", "▏", "▕", "🭿", "🭼" }

local vertical_laout = {
    layout_strategy = "vertical",
    preview_title = "",
    layout_config = {
        mirror = true
    },
    borderchars = {
        prompt = prompt_chars,
        preview = vert_preview_chars,
        results = U.get_border_chars("telescope"),
    },
}

local horizontal_layout = {
    layout_strategy = "horizontal",
    preview_title = "",
    borderchars = {
        prompt = prompt_chars,
        results = U.get_border_chars("telescope"),
        preview = U.get_border_chars("telescope"),
    },
    layout_config = { preview_width = 0.6 }
}

ts.setup({
    defaults = {
        sort_mru = true,
        sorting_strategy = "ascending",
        layout_config = {
            prompt_position = "top",
            height = 0.9,
            width = 0.9,
        },
        border = true,
        borderchars = {
            prompt = prompt_chars,
            results = U.get_border_chars("telescope"),
            preview = U.get_border_chars("telescope"),
        },
        multi_icon = "",
        entry_prefix = "   ",
        prompt_prefix = "   ",
        selection_caret = "  ",
        hl_result_eol = true,
        results_title = "",
        winblend = 0,
        wrap_results = false,
        mappings = { i = { ["<Esc>"] = require("telescope.actions").close } },
        preview = { treesitter = true },
    },
    pickers = {
        lsp_references = vertical_laout,
        diagnostics = vertical_laout,
        live_grep = vertical_laout,
        help_tags = horizontal_layout,
        find_files = horizontal_layout,
        buffers = horizontal_layout,
        lsp_document_symbols = horizontal_layout,
    }
})

vim.api.nvim_create_autocmd('User', {
    pattern = 'TelescopePreviewerLoaded',
    callback = function()
        vim.opt_local.number = true
        require("ibl").setup_buffer(0, { enabled = true })
    end,
})

-- Extensions.
ts.load_extension("notify")
