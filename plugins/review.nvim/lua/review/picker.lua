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
        })
        :find()
end

return M
