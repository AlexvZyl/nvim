local h = require("tests.helpers")

local T = {}

-- Not installed in CI. Records what the picker asks telescope for.
local telescope = { config = {}, extensions = {} }
local picked, replacement

package.preload["telescope"] = function()
    return {
        register_extension = function(extension)
            return extension
        end,
        load_extension = function(name)
            if not telescope.extensions[name] then
                local extension = require("telescope._extensions." .. name)
                extension.setup(telescope.config[name])
                telescope.extensions[name] = extension.exports
            end
            return telescope.extensions[name]
        end,
    }
end
package.preload["telescope.make_entry"] = function()
    return {
        gen_from_file = function()
            return function(path)
                return {
                    value = path,
                    display = function()
                        return "icon " .. path, { { { 0, 4 }, "Icon" } }
                    end,
                }
            end
        end,
    }
end
package.preload["telescope.finders"] = function()
    return {
        new_table = function(finder)
            return finder
        end,
    }
end
package.preload["telescope.config"] = function()
    return {
        values = {
            file_sorter = function() end,
        },
    }
end
package.preload["telescope.pickers"] = function()
    return {
        new = function(opts, spec)
            return {
                find = function()
                    picked = { opts = opts, spec = spec }
                    spec.attach_mappings(0)
                end,
            }
        end,
    }
end
package.preload["telescope.actions"] = function()
    return {
        select_default = {
            replace_if = function(_, condition, action)
                replacement = { condition = condition, action = action }
            end,
        },
        close = function() end,
    }
end
package.preload["telescope.actions.state"] = function()
    return {
        get_selected_entry = function()
            return telescope.selected
        end,
    }
end

-- file.txt deleted and other.txt added, with the picker opened. Returns its spec and the main window.
local function pick(opts)
    h.repo(h.lines(5), h.lines(5))
    h.commit({ ["other.txt"] = { "a" } })
    h.git("rm", "-q", "file.txt")
    h.git("commit", "-qm", "delete")
    local main = h.review()
    telescope.config.review = { prompt_prefix = "> " }
    telescope.extensions = {}
    require("review").files(opts)
    return picked.spec, main
end

local function entry(spec, path)
    return spec.finder.entry_maker(path)
end

function T.the_picker_lists_the_changed_files()
    local spec = pick({ layout_strategy = "vertical" })
    require("review").stop()
    local results = vim.deepcopy(spec.finder.results)
    table.sort(results)
    assert(vim.deep_equal(results, { "file.txt", "other.txt" }), vim.inspect(results))
    -- Telescope's config for the extension, under the options given.
    assert(picked.opts.prompt_prefix == "> " and picked.opts.layout_strategy == "vertical", vim.inspect(picked.opts))
end

function T.deleted_files_are_struck_through_in_the_picker()
    local spec = pick()
    local text, highlights = entry(spec, "file.txt"):display()
    local _, other_highlights = entry(spec, "other.txt"):display()
    require("review").stop()
    assert(vim.deep_equal(highlights[2], { { 4, #text }, "ReviewPanelDeleted" }), vim.inspect(highlights))
    assert(#other_highlights == 1, vim.inspect(other_highlights))
end

function T.picking_a_deleted_file_opens_it_as_deleted()
    local spec, main = pick()
    telescope.selected = entry(spec, "file.txt")
    local replaced = replacement.condition()
    -- Telescope focuses the window it was opened from first.
    vim.api.nvim_set_current_win(main)
    replacement.action()
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(main))
    telescope.selected = entry(spec, "other.txt")
    local other_replaced = replacement.condition()
    require("review").stop()
    assert(replaced and not other_replaced, vim.inspect({ replaced, other_replaced }))
    assert(name == "review://file.txt", name)
end

return T
