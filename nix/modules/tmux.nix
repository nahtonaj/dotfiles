{ config, pkgs, lib, flakePath, ... }:

{
  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile "${flakePath}/configs/tmux/tmux.conf";
  };

  # Auto-clone TPM on first activation
  home.activation.installTpm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
  '';
}
