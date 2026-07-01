{ config, lib, pkgs, ... }:

let
  # `omnigent host` runs as a persistent foreground process under systemd
  # (verified: it holds the connection and does not exit), so each attachment is
  # a long-running Type=simple service. Restart=always re-attaches after a
  # crash, idle exit, or reboot -- the same pattern as multica-daemon.
  #
  # NOTE: omnigent auth is INTERACTIVE (`omnigent login <url>`). When a server's
  # token expires, the attach exits non-zero and Restart=always crash-loops the
  # unit until the user re-runs `omnigent login`. The service cannot self-heal an
  # expired interactive credential.
  #
  # There are TWO host attachments, both auto-starting on boot:
  #   - omnigent-host           -> the App control plane (databricksapps.com)
  #   - omnigent-host-workspace -> a workspace-hosted omnigent server (--server)
  mkOmnigentHost = { description, execStart }: {
    Unit = {
      Description = description;
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = execStart;
      Environment = [
        "PATH=${config.home.homeDirectory}/.local/bin:${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      WorkingDirectory = config.home.homeDirectory;
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
in
{
  systemd.user.services = lib.mkIf pkgs.stdenv.isLinux {
    omnigent-host = mkOmnigentHost {
      description = "Omnigent host auto-attach (App control plane)";
      execStart = "${config.home.homeDirectory}/.local/bin/omnigent host https://omnigents-3272836215725701.aws.databricksapps.com";
    };

    omnigent-host-workspace = mkOmnigentHost {
      description = "Omnigent host auto-attach (workspace-hosted omnigent server)";
      execStart = "${config.home.homeDirectory}/.local/bin/omnigent host --server https://dbc-a5d4177a-49dc.cloud.databricks.com";
    };
  };
}
