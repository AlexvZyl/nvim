-- What the plugins share at runtime, in one module as each takes a while to find at startup.
local M = {}

-- The options of a plugin, the defaults until set up with others over them.
function M.config(defaults)
    local config = { options = vim.deepcopy(defaults) }
    function config.set(opts)
        config.options = vim.tbl_deep_extend("force", defaults, opts or {})
    end
    return config
end

-- Groups linked to others, or set to attributes when given a table, as defaults so colorschemes can override them.
function M.link(groups)
    for group, link in pairs(groups) do
        local hl = type(link) == "table" and link or { link = link }
        vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", hl, { default = true }))
    end
end

return M
