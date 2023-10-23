return {
    {
        'glacambre/firenvim',
        build = function()
            require("lazy").load({ plugins = "firenvim", wait = true })
            vim.fn["firenvim#install"](0)
        end,
        config = function() require('custom.configs.firenvim') end
    },
    {
        'rhysd/git-messenger.vim'
    },
    {
        'APZelos/blamer.nvim',
        config = function() require('custom.configs.blamer') end
    },
    {
        'mbbill/undotree'
    },
    {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v2.x',
        dependencies = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' }, -- Required
            {                      -- Optional
                'williamboman/mason.nvim',
                build = function()
                    pcall(vim.cmd, 'MasonUpdate')
                end,
            },
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional

            -- Autocompletion
            { 'hrsh7th/nvim-cmp' }, -- Required
            { 'hrsh7th/cmp-nvim-lsp' }, -- Required
            { 'L3MON4D3/LuaSnip' }, -- Required
        }
    },
    'mfussenegger/nvim-jdtls',
    'tpope/vim-commentary',
    {
      'tpope/vim-fugitive',
      lazy = false
    },
    'tpope/vim-repeat',
    'tpope/vim-rhubarb',
    'tpope/vim-surround',
    'tpope/vim-unimpaired',
    -- In order to modify the `lspconfig` configuration:
    {
      "neovim/nvim-lspconfig",
      dependencies = {
         "jose-elias-alvarez/null-ls.nvim",
       },
       config = function()
          require "plugins.configs.lspconfig"
          require "custom.configs.lspconfig"
       end,
    }
  }
