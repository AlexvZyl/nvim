return {
    -- General UI/UX
    {
        "glepnir/dashboard-nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("alex.plugins.ui.dashboard")
        end,
        lazy = false,
        priority = 999,
    },
    {
        "karb94/neoscroll.nvim",
        event = { "WinScrolled" },
        config = function()
            require("alex.plugins.ui.neoscroll-nvim").init()
        end,
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "VeryLazy" },
        config = function()
            require("alex.plugins.ui.indent-blankline")
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
            require("alex.plugins.ui.todo")
        end,
    },
    {
        "stevearc/oil.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("alex.plugins.ui.oil-nvim")
        end,
        lazy = false,
    },
    {
        "nvim-telescope/telescope.nvim",
        cmd = { "Telescope" },
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-lua/popup.nvim",
            {
                -- Currently only using these enhancements with telescope.
                "stevearc/quicker.nvim",
                config = function()
                    require("alex.plugins.ui.quicker")
                end,
            },
        },
        config = function()
            require("alex.plugins.ui.telescope")
        end,
    },
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        lazy = false,
        config = function()
            require("alex.plugins.ui.lualine")
        end,
    },
    {
        "folke/noice.nvim",
        dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
        event = { "VeryLazy" },
        config = function()
            require("alex.plugins.ui.noice")
        end,
    },
    {
        -- This plugin has issues when lazy.
        "lewis6991/gitsigns.nvim",
        -- event = { "VeryLazy" },
        config = function()
            require("alex.plugins.ui.gitsigns")
        end,
        lazy = false,
    },
    {
        "sindrets/diffview.nvim",
        cmd = { "DiffviewClose", "DiffviewOpen" },
        config = function()
            require("alex.plugins.ui.diffview")
        end,
    },
    {
        "f-person/git-blame.nvim",
        keys = { "<leader>b" },
        config = function()
            require("alex.plugins.ui.git-blame")
        end,
    },

    -- Editing / movement.
    {
        "ggandor/leap.nvim",
        dependencies = "tpope/vim-repeat",
        keys = { "s", "S" },
        config = function()
            require("alex.plugins.ui.leap")
        end,
    },

    -- Language.
    {
        "mfussenegger/nvim-lint",
        -- Does not make sense to have a linter without a LSP.
        -- This will have to change if that ever happens.
        event = { "LspAttach" },
        config = function()
            require("alex.plugins.lang.linter")
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
        event = { "VeryLazy" },
        build = { ":TSUpdate" },
        config = function()
            require("alex.plugins.ui.treesitter")
        end,
    },
    {
        "folke/lazydev.nvim",
        dependencies = { "Bilal2453/luvit-meta" },
        ft = "lua",
        event = { "LspAttach" },
    },
    {
        "hrsh7th/nvim-cmp",
        event = { "LspAttach" },
        config = function()
            require("alex.plugins.lang.completion")
        end,
        dependencies = {
            "hrsh7th/cmp-omni",
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "saadparwaiz1/cmp_luasnip",
            {
                "L3MON4D3/LuaSnip",
                dependencies = { "rafamadriz/friendly-snippets" },
                build = "make install_jsregexp",
            },
        },
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
            require("alex.plugins.ui.nvim-web-devicons")
        end,
    },
    {
        -- Loaded by the native config.
        "neovim/nvim-lspconfig",
    },

    -- Bin (maybe to remove)
    {
        "folke/which-key.nvim",
        event = { "VeryLazy" },
        config = function()
            require("alex.plugins.ui.which-key")
        end,
    },
}
