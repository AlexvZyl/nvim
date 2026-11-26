require("statusline").setup({
    toggles = {
        {
            enabled = function()
                return vim.o.relativenumber
            end,
            icon = " ",
        },
        {
            enabled = function()
                return require("alex.native.lang").virtual_diagnostics
            end,
            icon = " ",
        },
        {
            enabled = function()
                return require("alex.plugins.no-neck-pain").enabled
            end,
            icon = " ",
        },
        {
            enabled = function()
                return require("alex.native.lang").format_enabled
            end,
            icon = "󰉼 ",
        },
        {
            enabled = function()
                return package.loaded.review ~= nil and require("review").view() == "since_review"
            end,
            icon = " ",
        },
    },
})
