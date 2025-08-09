require("diffview").setup({
    enhanced_diff_hl = true,
    hooks = {
        view_opened = function()
            vim.diagnostic.enable(false)
            require("diffview.actions").toggle_files()
        end,
        view_closed = function()
            vim.diagnostic.enable(true)
        end,
    },
    view = {
        merge_tool = {
            layout = "diff3_mixed",
        },
    },
})
