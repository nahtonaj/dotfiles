{ config, pkgs, flakePath, ... }:

{
  home.activation.createAerospaceSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ln -sfn "${config.home.homeDirectory}/dotfiles/.config/aerospace" "${config.xdg.configHome}/aerospace"
  '';
}
