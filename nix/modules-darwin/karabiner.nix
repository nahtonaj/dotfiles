{ config, pkgs, flakePath, ... }:

{
  xdg.configFile."karabiner".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/karabiner";
}
