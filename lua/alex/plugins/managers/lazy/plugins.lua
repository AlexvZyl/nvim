return {
    -- General UI/UX
    {
        "glepnir/dashboard-nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require("alex.plugins.ui.dashboard") end,
        lazy = false,
        priority = 999,
    },
    {
        "folke/todo-comments.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope.nvim",
        },
        config = function() require("alex.plugins.ui.todo") end,
        event = { "User NvimStartupDone" },
    },
    {
        "nvim-tree/nvim-web-devicons",
        config = function() require("alex.plugins.ui.nvim-web-devicons") end,
    },
    {
        "NvChad/nvim-colorizer.lua",
        event = { "User NvimStartupDone" },
        config = function() require("alex.plugins.ui.colorizer") end,
    },
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-lua/popup.nvim",
        },
        cmd = "Telescope",
        config = function() require("alex.plugins.ui.telescope") end,
    },
    {
        "nvim-lualine/lualine.nvim",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            "AndreM222/copilot-lualine",
        },
        event = { "User NvimStartupDone" },
        config = function() require("alex.plugins.ui.lualine") end,
    },
    {
        "folke/noice.nvim",
        dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
        event = { "User NvimStartupDone" },
        config = function() require("alex.plugins.ui.noice") end,
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "VeryLazy" },
        config = function() require("alex.plugins.ui.indent-blankline") end,
    },
    {
        "lewis6991/gitsigns.nvim",
        event = { "User NvimStartupDone" },
        config = function() require("alex.plugins.ui.gitsigns") end,
    },
    {
        "sindrets/diffview.nvim",
        cmd = { "DiffviewClose", "DiffviewOpen" },
        config = function() require("alex.plugins.ui.diffview") end,
    },
    {
        "folke/which-key.nvim",
        event = { "User NvimStartupDone" },
        config = function() require("alex.plugins.ui.which-key") end,
    },
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require("alex.plugins.ui.tree") end,
        keys = { "<leader>f", "gf" },
    },
    {
        "f-person/git-blame.nvim",
        cmd = { "GitBlameToggle" },
    },

    -- Language.
    {
        "zbirenbaum/copilot.lua",
        config = function() require("alex.plugins.lang.copilot") end,
        cmd = { "Copilot" },
        build = "Copilot auth",
    },
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "nvim-neotest/nvim-nio",
            {
                "rcarriga/nvim-dap-ui",
                config = function() require("alex.plugins.ui.dapui") end,
            },
        },
        event = { "User NvimStartupDone" },
        config = function() require("alex.plugins.lang.dap") end,
    },
    {
        "mfussenegger/nvim-lint",
        event = { "User NvimStartupDone" },
        config = function() require("alex.plugins.lang.linter") end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        dependencies = {
            "nvim-treesitter/nvim-treesitter-textobjects",
            "nvim-treesitter/playground",
        },
        event = { "User NvimStartupDone" },
        build = { ":TSUpdate" },
        config = function() require("alex.plugins.ui.treesitter") end,
    },
    {
        "neovim/nvim-lspconfig",
        config = function() require("alex.plugins.lang.lsp") end,
        -- If this is lazy, it seems that the lsp misses the FileType event
        lazy = false,
    },
    {
        "folke/lazydev.nvim",
        ft = "lua",
        dependencies = { "Bilal2453/luvit-meta" },
    },
    {
        "hrsh7th/nvim-cmp",
        event = { "User NvimStartupDone" },
        config = function() require("alex.plugins.lang.completion") end,
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
        event = { "User NvimStartupDone" },
        config = function() require("tmux").setup() end,
    },
    {
        "ggandor/leap.nvim",
        dependencies = "tpope/vim-repeat",
        keys = { "s", "S" },
        config = function() require("alex.plugins.ui.leap") end,
    },

    -- Themes
    {
        "AlexvZyl/nordic.nvim",
        branch = "dev",
        priority = 1000,
        config = function() require("alex.plugins.themes.nordic") end,
        lazy = true,
    },
    {
        "folke/tokyonight.nvim",
        priority = 1000,
        lazy = false,
        config = function() require("alex.plugins.themes.tokyonight") end,
    },
    {
        "sainnhe/gruvbox-material",
        lazy = true,
        priority = 1000,
        config = function() require("alex.plugins.themes.gruvbox") end,
    },

    -- Nice themes.
    --{ 'EdenEast/nightfox.nvim', lazy = true },
    --{ 'catppuccin/nvim', lazy = true },
    --{ 'sainnhe/everforest', lazy = true },
    --{ 'rebelot/kanagawa.nvim', lazy = true },
    --{ 'marko-cerovac/material.nvim', lazy = true },
    --{ 'navarasu/onedark.nvim', lazy = true },
    --{ 'Shatur/neovim-ayu', lazy = true },
    --{ 'oxfist/night-owl.nvim', lazy = true },
}
