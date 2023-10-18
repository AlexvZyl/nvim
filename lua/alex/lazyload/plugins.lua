return {
    -- General UI/UX
    {
        'glepnir/dashboard-nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        priority = 999,
        lazy = false,
        config = function() require 'alex.ui.dashboard' end,
    },
    {
        -- Required by other packages
        'nvim-tree/nvim-web-devicons',
        config = function() require 'alex.ui.nvim-web-devicons' end,
        lazy = true,
    },
    {
        'NvChad/nvim-colorizer.lua',
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.ui.colorizer' end,
    },
    {
        'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim', 'nvim-lua/popup.nvim' },
        cmd = 'Telescope',
        config = function() require 'alex.ui.telescope' end,
    },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.ui.lualine' end,
    },
    {
        'willothy/nvim-cokeline',
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-tree/nvim-web-devicons',
        },
        config = function() require 'alex.ui.cokeline' end,
        event = { 'BufWinEnter' },
    },
    {
        'folke/noice.nvim',
        dependencies = { 'MunifTanjim/nui.nvim', 'rcarriga/nvim-notify' },
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.ui.noice' end,
    },
    {
        'lukas-reineke/indent-blankline.nvim',
        event = { 'VeryLazy' },
        config = function() require 'alex.ui.indent-blankline' end,
    },
    {
        'RRethy/vim-illuminate',
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.ui/illuminate' end,
    },
    {
        'lewis6991/gitsigns.nvim',
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.ui.gitsigns' end,
    },
    {
        'sindrets/diffview.nvim',
        cmd = { 'DiffviewClose', 'DiffviewOpen' },
        config = function() require 'alex.ui.diffview' end,
    },
    {
        'folke/which-key.nvim',
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.ui.which-key' end,
    },
    {
        'sudormrfbin/cheatsheet.nvim',
        cmd = { 'Cheatsheet' },
    },
    {
        'nvim-tree/nvim-tree.lua',
        version = '*',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function() require 'alex.ui.tree' end,
    },

    -- Language/Tools/LSP/Comp
    {
        'mfussenegger/nvim-dap',
        dependencies = { 'rcarriga/nvim-dap-ui' },
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.lang.debugger' end,
    },
    {
        'folke/trouble.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        cmd = { 'TroubleToggle' },
        config = function() require 'alex.lang.lsp.trouble' end,
    },
    {
        'mfussenegger/nvim-lint',
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.lang.linter' end,
    },
    {
        'nvim-treesitter/nvim-treesitter',
        dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects', 'nvim-treesitter/playground' },
        event = { 'User NvimStartupDone' },
        build = { ':TSUpdate' },
        config = function() require 'alex.lang.treesitter' end,
    },
    {
        'neovim/nvim-lspconfig',
        config = function() require 'alex.lang.lsp' end,
        --event = { 'User NvimStartupDone' },
        -- If this is lazy, it seems that the lsp misses the FileType event
        lazy = false,
        dependencies = {
            {
                'folke/neodev.nvim',
                config = function() require 'alex.lang.tools.neodev' end,
            },
            {
                'williamboman/mason.nvim',
                build = ':MasonUpdate',
                config = function() require 'alex.lang.mason' end,
            },
        },
    },
    {
        'glepnir/lspsaga.nvim',
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.lang.lsp.lspsaga' end,
    },
    {
        'hrsh7th/nvim-cmp',
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.lang.completion' end,
        dependencies = {
            'hrsh7th/cmp-omni',
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            'hrsh7th/cmp-cmdline',
            'saadparwaiz1/cmp_luasnip',
            {
                'L3MON4D3/LuaSnip',
                dependencies = { 'rafamadriz/friendly-snippets' },
                build = 'make install_jsregexp',
            },
        },
    },
    {
        'ray-x/lsp_signature.nvim',
        event = { 'User NvimStartupDone' },
        config = function() require 'alex.lang.lsp.signature' end,
    },

    -- Compatibility/Support/Language tools
    {
        'aserowy/tmux.nvim',
        event = { 'User NvimStartupDone' },
        config = function() require('tmux').setup() end,
    },
    {
        'fladson/vim-kitty',
        event = { 'User NvimStartupDone' },
    },
    {
        'lervag/vimtex',
        ft = { 'tex', 'latex' },
        config = function() require 'alex.lang.tools.latex' end,
    },

    -- Editing/Modal
    {
        'preservim/nerdcommenter',
        event = { 'User NvimStartupDone' },
    },
    {
        'ggandor/leap.nvim',
        dependencies = 'tpope/vim-repeat',
        keys = { 's', 'S' },
        config = function() require 'alex.ui.leap' end,
    },

    -- Themes
    {
        'AlexvZyl/nordic.nvim',
        branch = 'dev',
        priority = 1000,
        config = function() require 'alex.themes.nordic' end,
        lazy = true,
    },
    {
        'folke/tokyonight.nvim',
        priority = 1000,
        lazy = false,
        config = function() require 'alex.themes.tokyonight' end,
    },

    -- Nice themes
    --{ 'sainnhe/gruvbox-material', lazy = true },
    --{ 'EdenEast/nightfox.nvim', lazy = true },
    --{ 'catppuccin/nvim', lazy = true },
    --{ 'sainnhe/everforest', lazy = true },
    --{ 'rebelot/kanagawa.nvim', lazy = true },
    --{ 'marko-cerovac/material.nvim', lazy = true },
    --{ 'navarasu/onedark.nvim', lazy = true },
    --{ 'Shatur/neovim-ayu', lazy = true },
    --{ 'oxfist/night-owl.nvim', lazy = true },
}
