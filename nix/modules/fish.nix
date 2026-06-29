{ config, pkgs, ... }:

{
  home.file.".config/fish".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/configs/fish";
}
