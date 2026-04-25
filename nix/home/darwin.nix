{ config, pkgs, ... }:

{
  home.homeDirectory = "/Users/jon.gao";

  imports = [
    ../modules-darwin/aerospace.nix
    ../modules-darwin/yabai.nix
    ../modules-darwin/sketchybar.nix
    ../modules-darwin/karabiner.nix
    ../modules-darwin/arca-tunnel.nix
  ];

  # macOS-only bidirectional symlinks
  home.file.".finicky.js" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/finicky.js";
    force = true;
  };
}
