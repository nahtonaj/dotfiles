{ config, pkgs, flakePath, ... }:

{
  xdg.configFile."karabiner".source = "${flakePath}/.config/karabiner";
}
