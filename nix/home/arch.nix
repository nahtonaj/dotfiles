{ config, pkgs, ... }:

{
  home.username = "jon";
  home.homeDirectory = "/home/jon";

  imports = [
    ../modules/fish.nix
    ../modules/hyprland.nix
  ];
}
