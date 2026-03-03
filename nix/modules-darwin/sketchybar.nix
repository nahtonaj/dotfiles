{ config, pkgs, flakePath, ... }:

{
  xdg.configFile."sketchybar".source = "${flakePath}/.config/sketchybar";
}
