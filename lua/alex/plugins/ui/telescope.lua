local ts = require("telescope")
local U = require("alex.utils")

local prompt_chars = { "▔", "▕", " ", "▏", "🭽", "🭾", "▕", "▏" }
local vert_preview_chars =
    { " ", "▕", "▁", "▏", "▏", "▕", "🭿", "🭼" }

local vertical_layout = {
    layout_strategy = "vertical",
    preview_title = "",
    layout_config = {
        mirror = true,
    },
    borderchars = {
        prompt = prompt_chars,
        preview = vert_preview_chars,
        results = U.get_border_chars("telescope"),
    },
}

local horizontal_layout = {
    layout_strategy = "horizontal",
    wrap_results = false,
    preview_title = "",
    borderchars = {
        prompt = prompt_chars,
        results = U.get_border_chars("telescope"),
        preview = U.get_border_chars("telescope"),
    },
    layout_config = { preview_width = 0.57 },
}

local small_layout = {
    preview = false,
    layout_config = {
        height = 0.45,
        width = 0.45,
    },
}

ts.setup({
    defaults = {
        sort_mru = true,
        sorting_strategy = "ascending",
        layout_config = {
            prompt_position = "top",
            height = 0.9,
            width = 0.8,
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
        wrap_results = true,
        mappings = { i = { ["<Esc>"] = require("telescope.actions").close } },
        preview = { treesitter = true },
    },
    pickers = {
        lsp_references = vertical_layout,
        diagnostics = vertical_layout,
        live_grep = horizontal_layout,
        help_tags = horizontal_layout,
        find_files = horizontal_layout,
        lsp_document_symbols = horizontal_layout,
        buffers = small_layout,
    },
})

vim.api.nvim_create_autocmd("User", {
    pattern = "TelescopePreviewerLoaded",
    callback = function()
        vim.opt_local.number = true
        require("ibl").setup_buffer(0, { enabled = true })
    end,
})

-- Extensions.
ts.load_extension("notify")
