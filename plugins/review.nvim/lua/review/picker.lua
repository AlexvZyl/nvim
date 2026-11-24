local session = require("review.session")

local M = {}

-- From the telescope extension config.
local defaults = {}

function M.setup(opts)
    defaults = opts or {}
end

-- File entries, with the paths of deleted files struck through after their icon.
local function struck_through(opts)
    local make = require("telescope.make_entry").gen_from_file(opts)
    return function(path)
        local entry = make(path)
        local file = session.by_key[session.prefix .. path]
        if file and file.deleted then
            local display = entry.display
            entry.display = function(e)
                local text, style = display(e)
                style = style or {}
                local start = opts.disable_devicons and 0 or (style[1] and style[1][1][2] or 0)
                table.insert(style, { { start, #text }, "ReviewPanelDeleted" })
                return text, style
            end
        end
        return entry
    end
end

-- Telescope picker of the changed files.
function M.open(opts)
    -- Loading the extension runs its setup with `extensions.review`, which sets the defaults.
    pcall(require("telescope").load_extension, "review")
    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    local conf = require("telescope.config").values
    require("telescope.pickers")
        .new(opts, {
            prompt_title = "Review files",
            finder = require("telescope.finders").new_table({
                results = vim.tbl_map(function(file)
                    return file.path
                end, session.files),
                entry_maker = struck_through(opts),
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
