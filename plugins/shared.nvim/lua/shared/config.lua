local M = {}

-- The options of a plugin, the defaults until set up with others over them.
function M.new(defaults)
    local config = { options = vim.deepcopy(defaults) }
    function config.set(opts)
        config.options = vim.tbl_deep_extend("force", defaults, opts or {})
    end
    return config
end

return M
