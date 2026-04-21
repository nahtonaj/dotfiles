{ config, pkgs, flakePath, ... }:

{
  home.packages = [ pkgs.zellij ];

  home.activation.createZellijSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.configHome}/zellij"
    ln -sfn "${config.home.homeDirectory}/dotfiles/.config/zellij/config.kdl" "${config.xdg.configHome}/zellij/config.kdl"
  '';
}
