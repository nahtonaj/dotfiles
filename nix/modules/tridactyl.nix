{ config, pkgs, flakePath, ... }:

{
  home.activation.createTridactylSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ln -sfn "${config.home.homeDirectory}/dotfiles/configs/tridactylrc" "$HOME/.tridactylrc"
  '';
}
