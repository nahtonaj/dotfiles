-------------------------------------------------------------
-- General Neovim settings and configuration
-----------------------------------------------------------

local home = os.getenv("HOME")
local g = vim.g
local opt = vim.opt
local opt_global = vim.opt_global

g.mapleader = ' '

-- disable language provider support (lua and vimscript plugins only)
g.loaded_perl_provider = 0
g.loaded_ruby_provider = 0
g.loaded_node_provider = 0
g.loaded_python_provider = 0
g.loaded_python3_provider = 0

-- disable unused stuff
g.loaded = 1
g.loaded_netrw = 1
g.loaded_netrwPlugin = 1
g.loaded_2html_plugin = 1
g.loaded_tutor_mode_plugin = 1
g.loaded_matchit = 1  -- use vim-matchup
g.loaded_matchparen = 1  -- use vim-matchup

g.gutentags_exclude_filetypes = { 'gitcommit','gitconfig','gitrebase','gitsendemail','git' }
g.gutentags_ctags_exclude = { 'build/*', 'exclude-pat-two-*' }

-- basic settings
vim.cmd('filetype plugin on')
g.completeopt = { "menuone", "noinsert", "noselect" }
opt_global.shortmess:remove("F")
opt.encoding = "utf-8"
opt.backspace = "indent,eol,start" -- backspace works on every char in insert mode
opt.history = 1000
opt.startofline = true
-- opt.clipboard = 'unnamedplus'
opt.textwidth = 120

-- wait time
-- opt.timeout = false
opt.timeoutlen = 300
opt.ttimeout = true
opt.ttimeoutlen = 100

-- display
opt.showmatch  = true -- show matching brackets
opt.scrolloff = 3 -- always show 3 rows from edge of the screen
opt.synmaxcol = 300 -- stop syntax highlight after x lines for performance
opt.laststatus = 2 -- always show status line

opt.list = false -- do not display white characters
opt.foldenable = false
opt.foldlevel = 4 -- limit folding to 4 levels
opt.foldmethod = 'syntax' -- use language syntax to generate folds
opt.wrap = false --do not wrap lines even if very long
opt.eol = false -- show if there's no eol char
opt.showbreak= '↪' -- character to show when line is broken

opt.termguicolors = true

opt.colorcolumn = "120"

-- sidebar
opt.number = true -- line number on the left
opt.numberwidth = 3 -- always reserve 3 spaces for line number
opt.signcolumn = 'yes' -- keep 1 column for coc.vim  check
opt.modelines = 0
opt.showcmd = true -- display command in bottom bar
opt.relativenumber = true

-- search
opt.incsearch = false -- starts searching as soon as typing, without enter needed
opt.ignorecase = true -- ignore letter case when searching
opt.smartcase = true -- case insentive unless capitals used in search

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
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.cindent = true
opt.autoindent = true
opt.smartindent = true
opt.expandtab = true -- expand tab to spaces
opt.smarttab = true
opt.cinoptions = 's,e0,n0,f0,{0,}0,^0,L-1,:s,=s,l0,b0,gs,hs,ps,ts,is,+s,c3,C0,/0,(0,us,U0,w0,W0,m0,j1,J0,)20,*70,#0'
