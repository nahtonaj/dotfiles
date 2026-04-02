{ config, pkgs, flakePath, ... }:

{
  home.activation.createKarabinerSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ln -sfn "${config.home.homeDirectory}/dotfiles/.config/karabiner" "${config.xdg.configHome}/karabiner"
  '';
}
