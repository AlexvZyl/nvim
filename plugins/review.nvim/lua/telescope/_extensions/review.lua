-- `:Telescope review` picks a changed file. Configured with `extensions.review` in telescope's setup.
local session = require("review.session")

-- Set by telescope's setup.
local defaults = {}

-- Strikes through deleted files' paths.
local function struck_through(opts)
    local make_entry = require("telescope.make_entry").gen_from_file(opts)
    return function(path)
        local entry = make_entry(path)
        local file = session.by_repo_path[session.cwd_prefix .. path]
        if file and file.is_deleted then
            local default_display = entry.display
            entry.display = function(this_entry)
                local text, highlights = default_display(this_entry)
                highlights = highlights or {}
                local path_start = opts.disable_devicons and 0 or (highlights[1] and highlights[1][1][2] or 0)
                table.insert(highlights, { { path_start, #text }, "ReviewPanelDeleted" })
                return text, highlights
            end
        end
        return entry
    end
end

local function pick(opts)
    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    local telescope_config = require("telescope.config").values
    require("telescope.pickers")
        .new(opts, {
            prompt_title = "Review files",
            finder = require("telescope.finders").new_table({
                results = vim.tbl_map(function(file)
                    return file.path
                end, session.files),
                entry_maker = struck_through(opts),
            }),
            sorter = telescope_config.file_sorter(opts),
            attach_mappings = function(prompt_buf)
                local actions = require("telescope.actions")
                local action_state = require("telescope.actions.state")
                local function selected_is_deleted()
                    local entry = action_state.get_selected_entry()
                    local file = entry and session.by_repo_path[session.cwd_prefix .. entry.value]
                    return file and file.is_deleted
                end
                actions.select_default:replace_if(selected_is_deleted, function()
                    local path = action_state.get_selected_entry().value
                    actions.close(prompt_buf)
                    vim.api.nvim_win_set_buf(0, require("review.deleted").open(path))
                end)
                return true
            end,
        })
        :find()
end

return require("telescope").register_extension({
    setup = function(opts)
        defaults = opts or {}
    end,
    exports = {
        -- Warns when no review is running.
        review = function(opts)
            require("review").files(opts)
        end,
        pick = pick,
    },
})
