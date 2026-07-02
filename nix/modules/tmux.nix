{ config, pkgs, lib, flakePath, ... }:

{
  home.packages = [ pkgs.tmux ];

  # Symlink tmux.conf at the XDG path for bidirectional editing (no rebuild needed to reload).
  # This is the single canonical tmux config; we deliberately do NOT set programs.tmux.enable,
  # which would generate a competing ~/.config/tmux/tmux.conf that overrides these settings.
  home.file.".config/tmux/tmux.conf" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/tmux/tmux.conf";
    force = true;
  };

  # Auto-clone TPM on first activation
  home.activation.installTpm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
  '';

  # Tmux systemd service for session persistence (Linux only)
  systemd.user.services.tmux = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "tmux default session (detached)";
      Documentation = "man:tmux(1)";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "forking";
      Environment = "PATH=${config.home.homeDirectory}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
      ExecStart = "${pkgs.tmux}/bin/tmux new-session -d";
      ExecStop = "${pkgs.tmux}/bin/tmux kill-server";
      KillMode = "control-group";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
