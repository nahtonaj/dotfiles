{ config, pkgs, ... }:

{
  home.homeDirectory = "/Users/jon.gao";

  imports = [
    ../modules-darwin/aerospace.nix
    ../modules-darwin/sketchybar.nix
    ../modules-darwin/karabiner.nix
  ];
}
