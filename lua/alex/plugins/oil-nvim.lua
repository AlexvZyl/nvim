require("oil").setup({
    delete_to_trash = true,
    watch_for_changes = true,
    default_file_explorer = true,
})

require("alex.keymaps").oil()

require("oil.view").set_is_hidden_file(function(_, _)
    return false
end)

vim.api.nvim_create_autocmd("User", {
    pattern = "OilEnter",
    callback = function()
        require("alex.native.winbar").set_winbar()
    end,
})
