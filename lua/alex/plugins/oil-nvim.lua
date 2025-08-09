require("oil").setup({
    delete_to_trash = true,
    view_options = {
        show_hidden = true,
        is_hidden_file = function(name, bufnr)
            return false
        end,
        is_always_hidden = function(name, bufnr)
            return false
        end,
    },
    watch_for_changes = true,
    default_file_explorer = true,
})

require("alex.keymaps").oil()

require("oil.view").set_is_hidden_file(function(name, buffer)
    return false
end)
