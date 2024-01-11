return {
    {
    'glacambre/firenvim',
    lazy = not vim.g.started_by_firenvim,
    build = function()
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
    {
        'mfussenegger/nvim-dap',
    },
    'tpope/vim-commentary',
    {
    'tpope/vim-fugitive',
    lazy = false
    },
    'tpope/vim-repeat',
    'tpope/vim-rhubarb',
    'tpope/vim-surround',
    'tpope/vim-unimpaired',
    "tpope/vim-sleuth",
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
    },
    {
      "nvim-treesitter/nvim-treesitter",
      event = { "BufReadPre", "BufNewFile" },
      build = ":TSUpdate",
      dependencies = {
        "nvim-treesitter/nvim-treesitter-textobjects",
        "windwp/nvim-ts-autotag",
      },
      config = function()
        -- import nvim-treesitter plugin
        local treesitter = require("nvim-treesitter.configs")

        -- configure treesitter
        treesitter.setup({ -- enable syntax highlighting
          highlight = {
            enable = true,
          },
          -- enable indentation
          indent = { enable = true },
          -- enable autotagging (w/ nvim-ts-autotag plugin)
          autotag = {
            enable = true,
          },
          -- ensure these language parsers are installed
          ensure_installed = {
            "json",
            "yaml",
            "html",
            "markdown",
            "markdown_inline",
            "bash",
            "lua",
            "vim",
            "dockerfile",
            "gitignore",
            "java",
            "ruby",
            "xml",
            "python"
          },
          incremental_selection = {
            enable = true,
            keymaps = {
              init_selection = "<C-space>",
              node_incremental = "<C-space>",
              scope_incremental = false,
              node_decremental = "<bs>",
            },
          },
          -- enable nvim-ts-context-commentstring plugin for commenting tsx and jsx
          context_commentstring = {
            enable = true,
            enable_autocmd = false,
          },
        })
      end,
    },
    'rcarriga/nvim-dap-ui',
    'theHamsta/nvim-dap-virtual-text',
    {
        'neoclide/coc.nvim',
        branch = 'release',
    },
    'lepture/vim-jinja'
  }
