{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  # Symlink to NormalNvim (git submodule) using mkOutOfStoreSymlink
  # so lazy.nvim can write to lazy-lock.json
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/.config/nvim";
}
