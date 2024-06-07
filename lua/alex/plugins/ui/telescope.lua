local ts = require("telescope")
local U = require("alex.utils")

local prompt_chars = { "▔", "▕", " ", "▏", "🭽", "🭾", "▕", "▏" }
local vert_preview_chars = { " ", "▕", "▁", "▏", "▏", "▕", "🭿", "🭼" }

local vertical_laout = {
    layout_strategy = "vertical",
    layout_config = { mirror = true },
    preview_title = "",
    borderchars = {
        prompt = prompt_chars,
        preview = vert_preview_chars,
        results = U.get_border_chars("telescope"),
    }
}

ts.setup({
    defaults = {
        sort_mru = true,
        sorting_strategy = "ascending",
        layout_config = { prompt_position = "top" },
        borderchars = {
            prompt = prompt_chars,
            results = U.get_border_chars("telescope"),
            preview = U.get_border_chars("telescope"),
        },
        border = true,
        multi_icon = "",
        entry_prefix = "   ",
        prompt_prefix = "   ",
        selection_caret = "  ",
        hl_result_eol = true,
        results_title = "",
        winblend = 0,
        wrap_results = false,
        mappings = { i = { ["<Esc>"] = require("telescope.actions").close } },
        preview = { treesitter = true }
    },
    pickers = {
        lsp_references = vertical_laout,
        diagnostics = vertical_laout,
        lsp_document_symbols = vertical_laout,
        live_grep = vertical_laout
    }
})

ts.load_extension("notify")

vim.api.nvim_create_autocmd('User', {
    pattern = 'TelescopePreviewerLoaded',
    callback = function()
        vim.opt_local.number = true
        require("ibl").setup_buffer(0, { enabled = true })
    end,
})
