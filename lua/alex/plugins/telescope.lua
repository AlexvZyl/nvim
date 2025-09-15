local TS = require("telescope")
local U = require("alex.utils")

----------------------------------------------------------------------------------------------------
--- Defaults

local actions = require("telescope.actions")

local ACTIONS = {
    ["<Esc>"] = actions.close,
    ["<C-Esc>"] = actions.close,
    ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
}

local MAPPINGS = {
    i = ACTIONS,
    n = ACTIONS,
}

local SINGLE_SELECT_ICON = "   "
local SINGLE_SELECT_ENTRY_PREFIX = "   "
local LARGE_WIDTH = 141
local SMALL_WIDTH = 120
local LARGE_HEIGHT = 1.0
local FULL_HEIGHT = 1000 -- HACK: 1.0 does not seem to work
local WITH_PREVIEW_WITH = 190

----------------------------------------------------------------------------------------------------
--- Templates.

local baseline = {
    previewer = false,
    preview_title = false,
    dynamic_preview_title = false,
    results_title = false,
    line_width = "full",

    layout_config = {
        prompt_position = "top",
    },

    border = true,
    borderchars = {
        prompt = U.border_chars_telescope_combine_top,
        results = U.border_chars_telescope_combine_bottom,
        preview = U.border_chars_telescope_default,
    },

    sort_mru = true,
    sorting_strategy = "ascending",
    multi_icon = "   ",
    entry_prefix = "   ",
    prompt_prefix = "   ",
    selection_caret = "   ",
    hl_result_eol = true,
    wrap_results = true,
    winblend = 0,

    mappings = MAPPINGS,
    preview = { treesitter = true },
}

local large_no_preview = {
    layout_strategy = "center",
    layout_config = {
        height = 39,
        width = LARGE_WIDTH,
    },
}
large_no_preview = U.merge(baseline, large_no_preview)

local small_no_preview = {
    layout_strategy = "center",
    layout_config = {
        height = 30,
        width = SMALL_WIDTH,
    },
}
small_no_preview = U.merge(baseline, small_no_preview)

local single_select_small = {
    entry_prefix = SINGLE_SELECT_ENTRY_PREFIX,
    selection_caret = SINGLE_SELECT_ICON,
    previewer = false,
    multi_icon = "",
}
single_select_small = U.merge(small_no_preview, single_select_small)

local preview_horizontal = {
    layout_strategy = "horizontal",
    previewer = true,
    borderchars = {
        prompt = U.border_chars_telescope_default,
        results = U.border_chars_telescope_default,
        preview = U.border_chars_telescope_default,
    },
    layout_config = {
        height = FULL_HEIGHT,
        width = WITH_PREVIEW_WITH,
        preview_width = 100,
    },
}
preview_horizontal = U.merge(baseline, preview_horizontal)

local preview_vertical = {
    layout_strategy = "vertical",
    previewer = true,
    borderchars = {
        prompt = U.border_chars_telescope_default,
        results = U.border_chars_telescope_default,
        preview = U.border_chars_telescope_default,
    },
    layout_config = {
        height = FULL_HEIGHT,
        width = LARGE_WIDTH,
        preview_height = 25,
        mirror = true,
    },
}
preview_vertical = U.merge(baseline, preview_vertical)

----------------------------------------------------------------------------------------------------
--- Configure

TS.setup({
    defaults = large_no_preview,
    pickers = {
        oldfiles = small_no_preview,
        find_files = small_no_preview,
        registers = small_no_preview,

        spell_suggest = single_select_small,

        jumplist = preview_horizontal,
        live_grep = preview_horizontal,
        highlights = preview_horizontal,

        lsp_references = preview_vertical,
        lsp_definitions = preview_vertical,
        lsp_implementations = preview_vertical,
        diagnostics = preview_vertical,
        lsp_document_symbols = U.merge(preview_vertical, {
            symbol_width = 0.75,
        }),

        -- Custom.

        help_tags = U.merge(small_no_preview, {
            prompt_title = "Neovim help",
            mappings = { i = { ["<CR>"] = actions.select_vertical } },
        }),

        buffers = U.merge(small_no_preview, {
            ignore_current_buffer = true,
            file_ignore_patters = { "\\." },

            on_complete = {
                function(picker)
                    vim.schedule(function()
                        picker:set_selection(0)
                    end)
                end,
            },
        }),

        man_pages = U.merge(preview_horizontal, {
            prompt_title = "Manpages",
            mappings = { i = { ["<CR>"] = actions.select_vertical } },
        }),

        current_buffer_fuzzy_find = U.merge(preview_horizontal, {
            prompt_title = "Buffer",
            previewer = false,
        }),
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
