{ config, pkgs, flakePath, ... }:

{
  home.packages = [ pkgs.zellij ];

  xdg.configFile."zellij/config.kdl".source = "${flakePath}/.config/zellij/config.kdl";
}
