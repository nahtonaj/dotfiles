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

  # Tmux systemd service for session persistence
  systemd.user.services.tmux = {
    Unit = {
      Description = "tmux default session (detached)";
      Documentation = "man:tmux(1)";
    };
    Service = {
      Type = "forking";
      ExecStart = "${pkgs.tmux}/bin/tmux new-session -d";
      # Save is handled solely by continuum auto-save (every 15 min)
      # Restore is handled solely by @continuum-restore 'on' in tmux.conf
      ExecStop = "${pkgs.tmux}/bin/tmux kill-server";
      KillMode = "control-group";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
