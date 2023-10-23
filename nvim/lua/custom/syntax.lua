require("nvim-treesitter.configs").setup(
  highlight = {
    enable = true,
  },
  indent = { enable = true },
  ensure_installed = {
    "json",
    "yaml",
    "java",
    "python",
    "bash",
    "xml",
    "html",
    "ruby",
  }
)
