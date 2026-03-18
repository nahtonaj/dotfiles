{ config, pkgs, flakePath, ... }:

{
  home.packages = [ pkgs.zellij ];

  xdg.configFile."zellij/config.kdl".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/zellij/config.kdl";
}
