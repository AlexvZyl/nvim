if vim.fn.argc() == 0 then
    local startup_win = vim.api.nvim_get_current_win()

    require("lazy").show()

    vim.schedule(function()
        if vim.api.nvim_win_is_valid(startup_win) then
            vim.api.nvim_win_call(startup_win, function()
                require("alex.native.statuscolumn").default()
            end)
        end
    end)
end

return {}
