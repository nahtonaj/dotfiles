{ config, pkgs, flakePath, ... }:

{
  home.activation.createIdeavimSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ln -sfn "${config.home.homeDirectory}/dotfiles/configs/ideavimrc" "$HOME/.ideavimrc"
  '';
}
