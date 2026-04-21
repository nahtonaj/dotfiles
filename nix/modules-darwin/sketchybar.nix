{ config, pkgs, flakePath, ... }:

{
  home.activation.createSketchybarSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ln -sfn "${config.home.homeDirectory}/dotfiles/.config/sketchybar" "${config.xdg.configHome}/sketchybar"
  '';
}
