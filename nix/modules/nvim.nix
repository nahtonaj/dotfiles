{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  # nvim config is the NormalNvim git submodule at dotfiles/.config/nvim.
  # ~/.config -> ~/dotfiles/.config (legacy symlink), so ~/.config/nvim
  # already resolves to the writable submodule — no xdg.configFile needed.
}
