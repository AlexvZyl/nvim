local TS = require("telescope")
local U = require("alex.utils")

local prompt_chars = U.border_chars_telescope_default
local vert_preview_chars = U.border_chars_telescope_default
if not U.is_default() then
    prompt_chars = U.border_chars_telescope_prompt_thin
    vert_preview_chars = U.border_chars_telescope_vert_preview_thin
end

----------------------------------------------------------------------------------------------------
--- Default

local actions = require("telescope.actions")

local ACTIONS = {
    ["<Esc>"]   = actions.close,
    ["<C-Esc>"] = actions.close,
    ["<C-q>"]   = actions.smart_send_to_qflist + actions.open_qflist,
}

local MAPPINGS = {
    i = ACTIONS,
    n = ACTIONS
}

local defaults = {
    layout_strategy = "vertical",
    preview_title = "",
    dynamic_preview_title = false,

    layout_config = {
        prompt_position = "top",
        mirror = true,
        preview_height = 0.6,
        height = 0.95,
        width = 0.7,
    },
    borderchars = {
        prompt = prompt_chars,
        preview = vert_preview_chars,
        results = U.get_border_chars("telescope"),
    },

    sort_mru = true,
    sorting_strategy = "ascending",
    border = true,
    multi_icon = "   ",
    entry_prefix = "   ",
    prompt_prefix = "   ",
    selection_caret = "   ",
    hl_result_eol = true,
    results_title = "",
    winblend = 0,
    wrap_results = true,

    mappings = MAPPINGS,
    -- BUG: This causes too many issues.
    preview = { treesitter = false, },

}

----------------------------------------------------------------------------------------------------
--- Custom

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

    multi_icon = "",
    entry_prefix = "   ",
    selection_caret = "  ",
}

local picker_register = {
    sort_mru = true,
    preview = false,
    wrap_results = false,
    layout_config = {
        height = 0.6,
        width = 0.6,
    },

    multi_icon = "",
    entry_prefix = "   ",
    selection_caret = "  ",
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

    multi_icon = "",
    entry_prefix = "   ",
    selection_caret = "  ",
}

local diagnostics = {
    sort_by = "severity",
    multi_icon = "",
    entry_prefix = "   ",
    selection_caret = "  ",
    preview_title = "",
}

local help_tags = {
    sort_by = "severity",
    multi_icon = "",
    entry_prefix = "   ",
    selection_caret = "  ",
    preview_title = "",
    mappings = { i = { ["<CR>"] = actions.select_vertical } },
}

local man_pages = {
    preview_title = "",
    mappings = { i = { ["<CR>"] = actions.select_vertical } },
}

----------------------------------------------------------------------------------------------------
--- Configure

TS.setup({
    defaults = defaults,
    pickers = {
        oldfiles = defaults,
        find_files = defaults,

        diagnostics = diagnostics,
        buffers = picker_buffer,
        registers = picker_register,

        lsp_definitions = small_lsp_layout,
        lsp_references = small_lsp_layout,
        lsp_implementations = small_lsp_layout,

        help_tags = help_tags,
        man_pages = man_pages,
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
