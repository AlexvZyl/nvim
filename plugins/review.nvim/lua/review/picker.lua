local session = require("review.session")

local M = {}

-- Telescope picker of the changed files.
function M.open()
    local conf = require("telescope.config").values
    require("telescope.pickers")
        .new({}, {
            prompt_title = "Review files",
            finder = require("telescope.finders").new_table({
                results = vim.tbl_map(function(file)
                    return file.path
                end, session.files),
                entry_maker = require("telescope.make_entry").gen_from_file({}),
            }),
            sorter = conf.file_sorter({}),
            previewer = conf.file_previewer({}),
        })
        :find()
end

return M
