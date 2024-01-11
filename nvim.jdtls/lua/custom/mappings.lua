local M = {}

M.general = {
  n = {
    ["<leader>n"] = { "<cmd> set wrap! <CR>", "Toggle wrap" },
    ["<C-p>"] = { "<cmd> Telescope <CR>", "Telescope" },
    ["<leader><leader>"] = { "<cmd> cclose <CR>", "Close quickfix" },

    ["gq"] = {
      function()
        vim.lsp.buf.format { async = true }
      end,
      "LSP formatting",
    },
  }
}

M.telescope = {
  n = {
    ["<leader>f<leader>"] = { "<cmd> Telescope resume <CR>", "Telescope resume" },
    ["<leader>fs"] = { "<cmd> Telescope lsp_document_symbols <CR>", "Find lsp document symbols" },
    ["<leader>fw"] = { "<cmd> Telescope lsp_dynamic_workspace_symbols <CR>", "Find lsp workspace symbols" },
  }
}

M.tabufline = {
  plugin = true,

  n = {
    -- cycle through buffers
    ["<leader><tab>"] = {
      function()
        require("nvchad.tabufline").tabuflineNext()
      end,
      "Goto next buffer",
    },

    ["<leader><leader><tab>"] = {
      function()
        require("nvchad.tabufline").tabuflinePrev()
      end,
      "Goto prev buffer",
    },

    -- close buffer + hide terminal buffer
    ["<leader>x"] = {
      function()
        require("nvchad.tabufline").close_buffer()
      end,
      "Close buffer",
    },
  },
}

return M
