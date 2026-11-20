local session = require("alex.native.review.session")

local M = {}

function M.open()
    require("telescope")
    local templates = require("alex.plugins.telescope")
    local make_entry = require("telescope.make_entry").gen_from_file({})
    require("telescope.pickers")
        .new(vim.tbl_extend("force", templates.large_no_preview, { prompt_title = "Review files" }), {
            finder = require("telescope.finders").new_table({
                results = vim.tbl_map(function(file)
                    return file.path
                end, session.files),
                entry_maker = function(line)
                    local entry = make_entry(line)
                    entry.text = ""
                    return entry
                end,
            }),
            sorter = require("telescope.config").values.generic_sorter({}),
        })
        :find()
end

return M
