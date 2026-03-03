{ config, pkgs, flakePath, ... }:

{
  xdg.configFile."aerospace".source = "${flakePath}/.config/aerospace";
}
