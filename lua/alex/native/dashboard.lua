if vim.fn.argc() == 0 then
    local startup_win = vim.api.nvim_get_current_win()
    require("lazy").show()
    vim.schedule(function()
        if vim.api.nvim_win_is_valid(startup_win) then
            vim.api.nvim_win_call(startup_win, function()
                vim.wo.signcolumn = "yes"
                require("alex.native.statuscolumn").default()
                pcall(vim.cmd, "Gitsigns attach")
            end)
        end
    end)
end

vim.api.nvim_create_autocmd("BufLeave", {
    callback = function(args)
        if vim.bo[args.buf].filetype ~= "lazy" then return end
        vim.schedule(function()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                local buf = vim.api.nvim_win_get_buf(win)
                if vim.bo[buf].filetype == "lazy" then
                    pcall(vim.api.nvim_win_close, win, true)
                end
            end
        end)
    end,
})

return {}
