{ config, pkgs, ... }:

{
  home.file.".config/hypr".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/configs/hypr";
}
