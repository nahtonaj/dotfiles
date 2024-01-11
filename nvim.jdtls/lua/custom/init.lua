local remap = require('custom.util').remap
local bufopts = { silent = true, noremap = true }
local home = os.getenv("HOME")
local g = vim.g
local opt = vim.opt
local opt_global = vim.opt_global

remap("n", "<leader>W", "<cmd>:w !diff % -<cr>", bufopts, "Diff since last write")

remap("v", "J", ":m '>+1<CR>gv=gv", bufopts, "Move line down")
remap("v", "K", ":m '<-2<CR>gv=gv", bufopts, "Move line up")

remap("n", "J", "mzJ`z")
remap("n", "<C-d>", "<C-d>zz")
remap("n", "<C-u>", "<C-u>zz")
remap("n", "<C-l>", "zL")
remap("n", "<C-h>", "zH")
remap("n", "n", "nzzzv")
remap("n", "N", "Nzzzv")

remap({"n", "v"}, "<leader>y", [["+y]])
remap("n", "<leader>Y", [["+Y]])

remap("n", "Q", "<nop>")

remap("n", "<C-k>", "<cmd>cnext<CR>zz")
remap("n", "<C-j>", "<cmd>cprev<CR>zz")
remap("n", "<leader>k", "<cmd>lnext<CR>zz")
remap("n", "<leader>j", "<cmd>lprev<CR>zz")

remap("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
remap("n", "<leader>*", [[:%s/<C-r>"/<C-r>"/gI<Left><Left><Left>]])

opt.termguicolors = true

opt.colorcolumn = "120"

vim.cmd('filetype plugin indent on')

-- sidebar
opt.number = true -- line number on the left
opt.numberwidth = 3 -- always reserve 3 spaces for line number
opt.signcolumn = 'yes' -- keep 1 column for coc.vim  check
opt.modelines = 0
opt.showcmd = true -- display command in bottom bar
opt.relativenumber = true

-- backup and undo
opt.backup = true
opt.swapfile = false
opt.backupdir = home .. '/.config/nvim/.backup/'
opt.directory = home .. '/.config/nvim/.swp/'
opt.undodir = home .. '/.config/nvim/.undo/'
opt.undofile = true
opt.undolevels = 1000
opt.undoreload = 10000

-- text format
-- opt.cindent = true
opt.autoindent = true
opt.smartindent = true
opt.expandtab = true -- expand tab to spaces
opt.smarttab = true
opt.wrap = false
-- opt.scrolloff = 999
-- opt.shiftwidth = 4
-- opt.tabstop = 4
