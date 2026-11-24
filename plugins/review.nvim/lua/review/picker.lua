local session = require("review.session")

local M = {}

-- From the telescope extension config.
local defaults = {}

function M.setup(opts)
    defaults = opts or {}
end

-- Telescope picker of the changed files.
function M.open(opts)
    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    local conf = require("telescope.config").values
    require("telescope.pickers")
        .new(opts, {
            prompt_title = "Review files",
            finder = require("telescope.finders").new_table({
                results = vim.tbl_map(function(file)
                    return file.path
                end, session.files),
                entry_maker = require("telescope.make_entry").gen_from_file(opts),
            }),
            sorter = conf.file_sorter(opts),
            attach_mappings = function(prompt)
                local actions = require("telescope.actions")
                local state = require("telescope.actions.state")
                local function deleted()
                    local entry = state.get_selected_entry()
                    local file = entry and session.by_key[session.prefix .. entry.value]
                    return file and file.deleted
                end
                actions.select_default:replace_if(deleted, function()
                    local path = state.get_selected_entry().value
                    actions.close(prompt)
                    vim.api.nvim_win_set_buf(0, require("review.render").deleted_buffer(path))
                end)
                return true
            end,
        })
        :find()
end

return M
