require("oil").setup({
    delete_to_trash = true,
    view_options = { show_hidden = true },
    watch_for_changes = true,
})

require("alex.keymaps").oil()
