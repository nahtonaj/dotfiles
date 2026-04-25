{ config, pkgs, ... }:

{
  launchd.agents.arca-tunnel = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.openssh}/bin/ssh"
        "arca.ssh"
        "-N"
        "-T"
        "-o" "ServerAliveInterval=30"
        "-o" "ServerAliveCountMax=3"
        "-o" "ExitOnForwardFailure=yes"
        "-o" "BatchMode=yes"
        "-L" "13100:127.0.0.1:13100"
        "-L" "13101:127.0.0.1:13101"
        "-L" "37777:127.0.0.1:37777"
        "-R" "27124:127.0.0.1:27124"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      ThrottleInterval = 10;
      ProcessType = "Background";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/arca-tunnel.out.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/arca-tunnel.err.log";
    };
  };
}
