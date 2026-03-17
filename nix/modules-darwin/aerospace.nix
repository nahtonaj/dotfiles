{ config, pkgs, flakePath, ... }:

{
  xdg.configFile."aerospace".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/aerospace";
}
