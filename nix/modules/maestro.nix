{ config, lib, pkgs, ... }:

{
  # Maestro (multica) agent daemon -- auto-starts at boot, restarts on crash
  systemd.user.services.multica-daemon = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Maestro (multica) agent daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "-/home/jon.gao/.local/bin/multica daemon stop";
      ExecStart = "${config.home.homeDirectory}/.local/bin/multica daemon start --foreground";
      Restart = "always";
      RestartSec = 5;
      Environment = [
        "PATH=${config.home.homeDirectory}/.local/bin:${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      WorkingDirectory = config.home.homeDirectory;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
