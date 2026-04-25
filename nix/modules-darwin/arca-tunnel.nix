{ config, pkgs, ... }:

let
  sshConfigPath = "${config.home.homeDirectory}/.config/arca-tunnel/ssh_config";
in
{
  # Dedicated ssh config for the arca-tunnel LaunchAgent. Mirrors the
  # auth/proxy setup from ~/.ssh/arca.ssh (which arca manages) but omits
  # its LocalForward/RemoteForward entries so this tunnel can run alongside
  # an active `arca start` session without port conflicts.
  home.file.".config/arca-tunnel/ssh_config".text = ''
    Host arca-tunnel
        Compression yes
        ProxyCommand bash /Users/jon.gao/.arca/tools/ssh_proxy_command.sh arca.ssh %p /Users/jon.gao/.arca/ssh_known_hosts_us-west-2 /Users/jon.gao/.arca/hostname /Users/jon.gao/.arca/ssh_proxy_command_log.txt
        ForwardAgent yes
        IdentityFile /Users/jon.gao/.dbcert/id_ssh
        IdentitiesOnly yes
        User jon.gao
        StrictHostKeyChecking accept-new
        UserKnownHostsFile /Users/jon.gao/.arca/ssh_known_hosts_us-west-2
        HashKnownHosts no
        LogLevel ERROR
        ServerAliveInterval 30
        ServerAliveCountMax 3
        ExitOnForwardFailure yes
        BatchMode yes
  '';

  launchd.agents.arca-tunnel = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.openssh}/bin/ssh"
        "-F" sshConfigPath
        "arca-tunnel"
        "-N"
        "-T"
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
