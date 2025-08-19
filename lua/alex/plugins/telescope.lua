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
    line_width = "full",

    layout_config = {
        prompt_position = "top",
        height = 28,
        width = 118,
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

local default_single_select = {
    entry_prefix = SINGLE_SELECT_ENTRY_PREFIX,
    selection_caret = SINGLE_SELECT_ICON,
    previewer = false,
    multi_icon = "",
}

local default_with_previewer = {
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

        spell_suggest = default_single_select,

        jumplist = default_with_previewer,
        live_grep = default_with_previewer,
        highlights = default_with_previewer,
        diagnostics = default_with_previewer,
        lsp_references = default_with_previewer,
        todo_telescope = default_with_previewer,
        lsp_definitions = default_with_previewer,
        lsp_implementations = default_with_previewer,
        lsp_document_symbols = default_with_previewer,

        help_tags = help_tags,
        man_pages = man_pages,
        buffers = picker_buffer,
        current_buffer_fuzzy_find = current_buffer_fuzzy,
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
