local M = {}

M.general = {
  n = {
    ["<leader>n"] = { "<cmd> set wrap! <CR>", "Toggle wrap" },
    ["<C-p>"] = { "<cmd> Telescope <CR>", "Telescope" },
  }
}

return M
