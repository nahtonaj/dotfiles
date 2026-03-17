{ config, pkgs, flakePath, ... }:

{
  home.file.".tridactylrc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/tridactylrc";
}
