local M = {}

M.opts = { overrides = {} }

function M.load(opts)
    -- Only another colorscheme has anything to clear, which is not the case at startup.
    if vim.g.colors_name and vim.g.colors_name ~= "default" then
        vim.api.nvim_command('hi clear')
    end
    vim.g.colors_name = "default"

    if opts then
        M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
    end

    vim.o.termguicolors = true

    local groups = require("default.groups")
    for group, config in pairs(M.opts.overrides) do
        groups[group] = vim.tbl_extend("force", groups[group] or {}, config)
    end

    require('default.utils').set_highlights_table(groups)
end

vim.api.nvim_create_user_command("Default", function(opts)
    if opts.args == "" then
        vim.cmd.colorscheme("default")
    elseif opts.args == "palette" then
        require("default.palette").print_palette()
    else
        vim.notify("Unknown argument: " .. opts.args, vim.log.levels.ERROR)
    end
end, {
    nargs = "?",
    complete = function(_, _)
        return { "palette" }
    end
})

return M
