{ config, pkgs, flakePath, ... }:

{
  home.file.".ideavimrc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/ideavimrc";
}
