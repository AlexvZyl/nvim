return {
    -- General UI/UX
    {
        "shortcuts/no-neck-pain.nvim",
        event = { "VeryLazy" },
        config = function()
            require("alex.plugins.no-neck-pain").setup()
        end,
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "VeryLazy" },
        config = function()
            require("alex.plugins.indent-blankline")
        end,
    },
    {
        "folke/todo-comments.nvim",
        -- This needs to be at stratup so that we can get the highliting.
        event = { "VeryLazy" },
        dependencies = {
            "nvim-lua/plenary.nvim",
            -- This is a dep but it does not have to be loaded with this plugin.
            -- "nvim-telescope/telescope.nvim",
        },
        config = function()
            require("alex.plugins.todo")
        end,
    },
    {
        "stevearc/oil.nvim",
        event = { "VeryLazy" },
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            require("alex.plugins.oil-nvim")
        end,
    },
    {
        "nvim-telescope/telescope.nvim",
        cmd = { "Telescope" },
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-lua/popup.nvim",
            "nvim-telescope/telescope-ui-select.nvim",
            {
                -- Currently only using these enhancements with telescope.
                "stevearc/quicker.nvim",
                config = function()
                    require("alex.plugins.quicker")
                end,
            },
        },
        config = function()
            require("alex.plugins.telescope")
        end,
    },
    {
        -- This plugin has issues when lazy.
        "lewis6991/gitsigns.nvim",
        -- event = { "VeryLazy" },
        config = function()
            require("alex.plugins.gitsigns")
        end,
        lazy = false,
    },

    -- Editing / movement.
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        lazy = false,
    },
    {
        url = "https://codeberg.org/andyg/leap.nvim",
        dependencies = "tpope/vim-repeat",
        keys = { "s", "S" },
        config = function()
            require("alex.plugins.leap")
        end,
    },

    -- Language.
    {
        "mfussenegger/nvim-lint",
        -- Does not make sense to have a linter without a LSP.
        -- This will have to change if that ever happens.
        event = { "LspAttach" },
        config = function()
            require("alex.plugins.linter")
        end,
    },
    {
        "folke/lazydev.nvim",
        dependencies = { "Bilal2453/luvit-meta" },
        ft = "lua",
        event = { "LspAttach" },
    },
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("alex.plugins.autopairs")
        end,
    },
    {
        "romus204/tree-sitter-manager.nvim",
        config = function()
            require("alex.plugins.tree-sitter-manager")
        end,
    },

    -- Other.
    {
        "aserowy/tmux.nvim",
        event = { "VeryLazy" },
        config = function()
            require("tmux").setup()
        end,
    },

    -- Dependencies.
    {
        "nvim-tree/nvim-web-devicons",
        config = function()
            require("alex.plugins.nvim-web-devicons")
        end,
    },
    {
        -- Loaded by the native config.
        "neovim/nvim-lspconfig",
        lazy = true,
    },

    -- Themes.
    {
        "AlexvZyl/default.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("default").load()
        end,
    },
}
