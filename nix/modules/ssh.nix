{ config, pkgs, lib, flakePath, ... }:

{
  home.file.".ssh/github-config-personal".text = ''
    Host github.com-personal
     HostName github.com
     IdentityFile ~/.ssh/id_rsa
     IdentitiesOnly yes
     User git
     StrictHostKeyChecking accept-new
  '';

  home.file.".ssh/rc" = {
    executable = true;
    text = ''
      #!/bin/bash
      MARKER="/tmp/.nix-bootstrap-done-$(id -u)"
      DOTFILES="$HOME/dotfiles"
      LOGFILE="$HOME/.nix-bootstrap.log"

      if [ ! -f "$MARKER" ] && [ -f "$DOTFILES/bootstrap.sh" ]; then
        LOCKFILE="/tmp/.nix-bootstrap-$(id -u).lock"
        if ! mkdir "$LOCKFILE" 2>/dev/null; then
          exit 0
        fi
        trap 'rmdir "$LOCKFILE" 2>/dev/null' EXIT
        bash "$DOTFILES/bootstrap.sh" >> "$LOGFILE" 2>&1
        if [ $? -eq 0 ]; then
          touch "$MARKER"
        fi
      fi

      # Required: handle X11 forwarding (sshd skips xauth when ~/.ssh/rc exists)
      if read proto cookie && [ -n "$DISPLAY" ]; then
        if [ "$(echo $DISPLAY | cut -c1-10)" = 'localhost:' ]; then
          echo "add unix:$(echo $DISPLAY | cut -c11-) $proto $cookie"
        else
          echo "add $DISPLAY $proto $cookie"
        fi | xauth -q -
      fi
    '';
  };

  # Tmux systemd service for session persistence
  systemd.user.services.tmux = {
    Unit = {
      Description = "tmux default session (detached)";
      Documentation = "man:tmux(1)";
    };
    Service = {
      Type = "forking";
      ExecStart = "${pkgs.tmux}/bin/tmux new-session -d";
      ExecStop = [
        "%h/.tmux/plugins/tmux-resurrect/scripts/save.sh"
        "${pkgs.tmux}/bin/tmux kill-server"
      ];
      KillMode = "control-group";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
