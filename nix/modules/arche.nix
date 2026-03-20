{ config, pkgs, lib, flakePath, ... }:

let
  homeDir = config.home.homeDirectory;

  # The Arche project lives at ~/arche with its own node_modules.
  archeHome = "${homeDir}/arche";

  serviceScript = pkgs.writeShellScript "arche-service" ''
    mkdir -p "$HOME/.local/log"

    # Find nvm node or fall back to Nix nodejs_22
    NVM_BIN=""
    for d in "$HOME"/.nvm/versions/node/*/bin; do
      [ -x "$d/node" ] && NVM_BIN="$d" && break
    done
    if [ -n "$NVM_BIN" ]; then
      export PATH="$NVM_BIN:$PATH"
    else
      export PATH="${pkgs.nodejs_22}/bin:$PATH"
    fi

    cd "${archeHome}"
    exec npx tsx src/daemon/start.ts
  '';
in
{
  # Systemd user service for the Arche MCP Server (Linux only)
  systemd.user.services.arche = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Arche MCP Server";
      After = [ "network-online.target" "default.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${serviceScript}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "ARCHE_DASHBOARD_PORT=7778"
        "ARCHE_DASHBOARD_HOST=0.0.0.0"
        "NODE_ENV=production"
        "npm_config_update_notifier=false"
      ];
      StandardOutput = "append:%h/.local/log/arche.log";
      StandardError = "append:%h/.local/log/arche.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
