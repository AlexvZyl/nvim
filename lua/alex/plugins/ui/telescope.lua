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

local defaults = {
    layout_strategy = "center",
    previewer = false,
    preview_title = false,
    dynamic_preview_title = false,
    results_title = false,

    layout_config = {
        prompt_position = "top",
        height = 27,
        width = 115,
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
    wrap_results = false,
    winblend = 0,

    mappings = MAPPINGS,
    preview = { treesitter = true },
}

-- NOTE: Intended to be used on top of the normal default.
local default_single_select = {
    entry_prefix = SINGLE_SELECT_ENTRY_PREFIX,
    selection_caret = SINGLE_SELECT_ICON,
    previewer = false,
    multi_icon = "",
}

local with_previewer = {
    previewer = true,
    preview_title = false,

    layout_config = {
        prompt_position = "top",
        anchor = "N",
    },
}

----------------------------------------------------------------------------------------------------
--- Custom

local picker_buffer = {
    previewer = false,
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

local help_tags = {
    prompt_title = "Neovim help",
    previewer = false,
    mappings = { i = { ["<CR>"] = actions.select_vertical } },
}

local man_pages = {
    prompt_title = "Manpages",
    previewer = false,
    mappings = { i = { ["<CR>"] = actions.select_vertical } },
}

local current_buffer_fuzzy = {
    prompt_title = "Buffer",
    previewer = false,
}

----------------------------------------------------------------------------------------------------
--- Configure

TS.setup({
    defaults = defaults,
    pickers = {
        oldfiles = defaults,
        find_files = defaults,
        registers = defaults,
        buffers = picker_buffer,

        lsp_definitions = with_previewer,
        lsp_references = with_previewer,
        lsp_implementations = with_previewer,
        lsp_document_symbols = with_previewer,
        diagnostics = with_previewer,
        highlights = with_previewer,
        live_grep = with_previewer,

        help_tags = help_tags,
        man_pages = man_pages,
        spell_suggest = default_single_select,
        current_buffer_fuzzy_find = current_buffer_fuzzy,
        todo_telescope = with_previewer,
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
