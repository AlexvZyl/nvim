local TS = require("telescope")
local U = require("alex.utils")

local prompt_chars = U.border_chars_telescope_default
local vert_preview_chars = U.border_chars_telescope_default
if not U.is_default() then
    prompt_chars = U.border_chars_telescope_prompt_thin
    vert_preview_chars = U.border_chars_telescope_vert_preview_thin
end

local picker_buffer = {
    preview = false,
    wrap_results = false,
    layout_config = {
        height = 0.5,
        width = 0.6,
    },
    sort_mru = true,
    ignore_current_buffer = true,
    file_ignore_patters = { "\\." },
    on_complete = {
        function(picker)
            vim.schedule(function()
                picker:set_selection(0)
            end)
        end,
    },
}

local picker_register = {
    sort_mru = true,
    preview = false,
    wrap_results = false,
    layout_config = {
        height = 0.6,
        width = 0.6,
    },
}

local small_lsp_layout = {
    layout_strategy = "vertical",
    preview_title = "",
    preview = true,
    wrap_results = false,
    layout_config = {
        height = 0.75,
        width = 0.65,
        mirror = true,
    },
    borderchars = {
        prompt = prompt_chars,
        preview = vert_preview_chars,
        results = U.get_border_chars("telescope"),
    },
}

local defaults = {
    layout_strategy = "vertical",
    preview_title = "",
    dynamic_preview_title = false,

    layout_config = {
        prompt_position = "top",
        mirror = true,
        preview_height = 0.55,
        height = 0.95,
        width = 0.75,
    },
    borderchars = {
        prompt = prompt_chars,
        preview = vert_preview_chars,
        results = U.get_border_chars("telescope"),
    },

    sort_mru = true,
    sorting_strategy = "ascending",
    border = true,
    multi_icon = "",
    entry_prefix = "   ",
    prompt_prefix = "   ",
    selection_caret = "  ",
    hl_result_eol = true,
    results_title = "",
    winblend = 0,
    wrap_results = true,
    mappings = {
        i = {
            ["<Esc>"] = require("telescope.actions").close,
            ["<C-Esc>"] = require("telescope.actions").close,
        },
    },

    -- BUG: This causes too many issues.
    preview = { treesitter = false },
}

TS.setup({
    defaults = defaults,
    pickers = {
        diagnostics = { sort_by = "severity", preview_title = "" },
        buffers = picker_buffer,
        registers = picker_register,

        lsp_definitions = small_lsp_layout,
        lsp_references = small_lsp_layout,
        lsp_implementations = small_lsp_layout,

        live_grep = { preview_title = "" },
        help_tags = {
            preview_title = "",
            mappings = { i = { ["<CR>"] = require("telescope.actions").select_vertical } },
        },
        oldfiles = { preview_title = "" },
        find_files = { preview_title = "" },
        lsp_document_symbols = { preview_title = "" },
        man_pages = {
            preview_title = "",
            mappings = { i = { ["<CR>"] = require("telescope.actions").select_vertical } },
        },
    },
})

vim.api.nvim_create_autocmd("User", {
    pattern = "TelescopePreviewerLoaded",
    callback = function()
        vim.opt_local.number = true
    end,
})

-- Extensions.
TS.load_extension("notify")
