{ config, pkgs, lib, flakePath, ... }:

{
  home.packages = [ pkgs.tmux ];

  # Direct symlink so edits to the dotfiles source take effect immediately
  # (no home-manager switch required after changing tmux.conf)
  home.activation.createTmuxSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.configHome}/tmux"
    ln -sfn "${config.home.homeDirectory}/dotfiles/configs/tmux/tmux.conf" "${config.xdg.configHome}/tmux/tmux.conf"
  '';

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
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "forking";
      Environment = "PATH=${config.home.homeDirectory}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
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
