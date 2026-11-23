-- Configured with `extensions.review` in the telescope setup, `:Telescope review` opens the picker.
return require("telescope").register_extension({
    setup = function(opts)
        require("review.picker").setup(opts)
    end,
    exports = {
        review = function(opts)
            require("review").files(opts)
        end,
    },
})
