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

local small = {
    layout_strategy = "center",
    layout_config = {
        height = 28,
        width = 114,
    },
}
small = U.merge(baseline, small)

local normal = {
    layout_strategy = "horizontal",
    previewer = true,
    borderchars = {
        prompt = U.border_chars_telescope_default,
        results = U.border_chars_telescope_default,
        preview = U.border_chars_telescope_default,
    },
    layout_config = {
        height = 0.925,
        width = 190,
        preview_width = 100,
    },
}
normal = U.merge(baseline, normal)

local single_select = {
    entry_prefix = SINGLE_SELECT_ENTRY_PREFIX,
    selection_caret = SINGLE_SELECT_ICON,
    previewer = false,
    multi_icon = "",
}
single_select = U.merge(small, single_select)

----------------------------------------------------------------------------------------------------
--- Custom

local picker_buffer = {
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
picker_buffer = U.merge(small, picker_buffer)

local help_tags = {
    prompt_title = "Neovim help",
    mappings = { i = { ["<CR>"] = actions.select_vertical } },
}
help_tags = U.merge(normal, help_tags)

local man_pages = {
    prompt_title = "Manpages",
    mappings = { i = { ["<CR>"] = actions.select_vertical } },
}
man_pages = U.merge(normal, man_pages)

local current_buffer_fuzzy = {
    prompt_title = "Buffer",
    previewer = false,
}
current_buffer_fuzzy = U.merge(normal, current_buffer_fuzzy)

----------------------------------------------------------------------------------------------------
--- Configure

TS.setup({
    defaults = small,
    pickers = {
        oldfiles = small,
        find_files = small,
        registers = small,

        spell_suggest = single_select,

        jumplist = normal,
        live_grep = normal,
        highlights = normal,
        diagnostics = normal,
        lsp_references = normal,
        lsp_definitions = normal,
        lsp_implementations = normal,
        lsp_document_symbols = normal,

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
