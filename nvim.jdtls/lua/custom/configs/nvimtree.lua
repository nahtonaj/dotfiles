local options = {
  actions = {
    open_file = {
      quit_on_open = true,
    },
  },
  view = {
    relative_number = true,
    number = true,
    float = true,
  }
}
require("nvim-tree").setup(options)
return options
