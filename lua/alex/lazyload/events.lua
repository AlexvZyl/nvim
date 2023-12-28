vim.api.nvim_create_autocmd('User', {
    callback = function(_)
        vim.api.nvim_exec_autocmds('User', {
            pattern = 'NvimStartupDone',
        })
    end,
    pattern = 'DashboardLoaded',
    once = true,
})

-- This will no longer work if Dashboard starts to set the value
vim.api.nvim_create_autocmd('BufModifiedSet', {
    callback = function(_)
        vim.api.nvim_exec_autocmds('User', {
            pattern = 'NvimStartupDone',
        })
    end,
    once = true,
})
