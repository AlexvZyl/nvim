local TS = require("telescope")
local U = require("alex.utils")

local prompt_chars = U.border_chars_telescope_default
local vert_preview_chars = U.border_chars_telescope_default
if not U.is_default() then
    prompt_chars = U.border_chars_telescope_prompt_thin
    vert_preview_chars = U.border_chars_telescope_vert_preview_thin
end

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

local picker_buffer = {
    preview = false,
    wrap_results = false,
    layout_config = {
        height = 0.4,
        width = 0.5,
    },
    sort_mru = true,
    ignore_current_buffer = true,
    file_ignore_patters = { "\\." },
    on_complete = {
        function(picker)
            vim.schedule(function()
                picker:set_selection(0)
            end)
        end
    }
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
        height = 0.65,
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
    mappings = {
        i = {
            ["<Esc>"] = require("telescope.actions").close,
            ["<C-Esc>"] = require("telescope.actions").close,
        },
    },
    preview = { treesitter = true },
}

TS.setup({
    defaults = defaults,
    pickers = {
        diagnostics = vertical_layout,
        live_grep = horizontal_layout,
        help_tags = horizontal_layout,
        oldfiles = horizontal_layout,
        find_files = horizontal_layout,
        buffers = picker_buffer,
        registers = picker_register,
        lsp_document_symbols = horizontal_layout,
        lsp_definitions = small_lsp_layout,
        lsp_references = small_lsp_layout,
        lsp_implementations = small_lsp_layout,
    },
})

vim.api.nvim_create_autocmd("User", {
    pattern = "TelescopePreviewerLoaded",
    callback = function() vim.opt_local.number = true end,
})

-- Extensions.
TS.load_extension("notify")
