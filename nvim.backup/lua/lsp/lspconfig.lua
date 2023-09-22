local lsp = require('lsp-zero').preset({})
local remap = require("me.util").remap

-- (Optional) Configure lua language server for neovim
require('lspconfig').lua_ls.setup(lsp.nvim_lua_ls())

lsp.on_attach(function(client, bufnr)
  lsp.default_keymaps({buffer = bufnr})
  local opts = {buffer = bufnr, remap = false}

  local bufopts = { noremap=true, silent=true, buffer=bufnr }
  remap('n', 'gD', vim.lsp.buf.declaration, bufopts, "Go to declaration")
  remap('n', 'gd', vim.lsp.buf.definition, bufopts, "Go to definition")
  remap('n', 'gi', vim.lsp.buf.implementation, bufopts, "Go to implementation")
  remap('n', 'K', vim.lsp.buf.hover, bufopts, "Hover text")
  remap('n', '<C-k>', vim.lsp.buf.signature_help, bufopts, "Show signature")
  remap('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts, "Add workspace folder")
  remap('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts, "Remove workspace folder")
  remap('n', '<space>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts, "List workspace folders")
  remap('n', '<space>D', vim.lsp.buf.type_definition, bufopts, "Go to type definition")
  remap('n', '<space>rn', vim.lsp.buf.rename, bufopts, "Rename")
  remap('n', '<space>ca', vim.lsp.buf.code_action, bufopts, "Code actions")
  vim.keymap.set('v', "<space>ca", "<ESC><CMD>lua vim.lsp.buf.range_code_action()<CR>",
    { noremap=true, silent=true, buffer=bufnr, desc = "Code actions" })
  remap('v', '<space>cf', function() vim.lsp.buf.format { async = true } end, bufopts, "Format lines")
  remap('n', '<space>cf', function() vim.lsp.buf.format { async = true } end, bufopts, "Format file")
  require("which-key").register({
    space = {
      name = "lsp",
    },
  })
end)

local java_cmds = vim.api.nvim_create_augroup('java_cmds', {clear = true})
local function enable_codelens(bufnr)
  pcall(vim.lsp.codelens.refresh)

  vim.api.nvim_create_autocmd('BufWritePost', {
    buffer = bufnr,
    group = java_cmds,
    desc = 'refresh codelens',
    callback = function()
      pcall(vim.lsp.codelens.refresh)
    end,
  })
end

local function enable_debugger(bufnr)
  require('jdtls').setup_dap({hotcodereplace = 'auto'})
  require('jdtls.dap').setup_dap_main_class_configs()

  local opts = {buffer = bufnr}
  vim.keymap.set('n', '<leader>df', "<cmd>lua require('jdtls').test_class()<cr>", opts)
  vim.keymap.set('n', '<leader>dn', "<cmd>lua require('jdtls').test_nearest_method()<cr>", opts)
end

local function jdtls_on_attach(client, bufnr)
  enable_debugger(bufnr)
  enable_codelens(bufnr)

  -- The following mappings are based on the suggested usage of nvim-jdtls
  -- https://github.com/mfussenegger/nvim-jdtls#usage
  
  local opts = {buffer = bufnr}
  vim.keymap.set('n', '<A-o>', "<cmd>lua require('jdtls').organize_imports()<cr>", opts)
  vim.keymap.set('n', 'crv', "<cmd>lua require('jdtls').extract_variable()<cr>", opts)
  vim.keymap.set('x', 'crv', "<esc><cmd>lua require('jdtls').extract_variable(true)<cr>", opts)
  vim.keymap.set('n', 'crc', "<cmd>lua require('jdtls').extract_constant()<cr>", opts)
  vim.keymap.set('x', 'crc', "<esc><cmd>lua require('jdtls').extract_constant(true)<cr>", opts)
  vim.keymap.set('x', 'crm', "<esc><Cmd>lua require('jdtls').extract_method(true)<cr>", opts)

  local function bemol()
    local bemol_dir = vim.fs.find({ '.bemol' }, { upward = true, type = 'directory'})[1]
    local ws_folders_lsp = {}
    if bemol_dir then
      local file = io.open(bemol_dir .. '/ws_root_folders', 'r')
      if file then

        for line in file:lines() do
          table.insert(ws_folders_lsp, line)
        end
        file:close()
      end
    end

    for _, line in ipairs(ws_folders_lsp) do
      vim.lsp.buf.add_workspace_folder(line)
    end

  end
  bemol()
end
require('lspconfig').jdtls.setup({
  single_file_support = false,
  on_attach = jdtls_on_attach,
  flags = {
    allow_incremental_sync = true,
  },
})


lsp.setup()

-- -- LSP Configuration

-- -- Use an on_attach function to only map the following keys
-- -- after the language server attaches to the current buffer
-- local on_attach = require("lsp.defaults").on_attach

-- -- add completion capability
-- local capabilities = vim.lsp.protocol.make_client_capabilities()
-- capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- local lspconfig = require('lspconfig')

-- lspconfig['dartls'].setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
-- }

-- lspconfig['lua_ls'].setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
--   settings = {
--     Lua = {
--       runtime = {
--         -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
--         version = 'LuaJIT',
--       },
--       diagnostics = {
--         -- Get the language server to recognize the `vim` global
--         globals = {'vim'},
--       },
--       workspace = {
--         -- Make the server aware of Neovim runtime files
--         library = vim.api.nvim_get_runtime_file("", true),
--         checkThirdParty = false,
--       },
--     },
--   }
-- }

-- lspconfig['ltex'].setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
--   filetypes = { "bib", "markdown", "org", "plaintex", "rst", "rnoweb", "tex", "pandoc" },
--   settings = {
--     ltex = {
--       language = "en-CA",
--     }
--   }
-- }

-- lspconfig['gopls'].setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
--   settings = {
--     gopls = {
--       analyses = {
--         unusedparams = true,
--       },
--       staticcheck = true,
--     },
--   }
-- }

-- lspconfig['pyright'].setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
--   settings = {
--     pyright = {
--       analysis = {
--         useLibraryCodeForTypes = true,
--       },
--     },
--   }
-- }

-- lspconfig['solargraph'].setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
-- }

-- lspconfig['tsserver'].setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
-- }
