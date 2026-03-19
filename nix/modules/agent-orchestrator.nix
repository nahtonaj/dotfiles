{ config, pkgs, lib, flakePath, ... }:

let
  homeDir = config.home.homeDirectory;

  # agent-orchestrator fork -- local clone replaces the global npm package.
  # All upstream bugs (ControllerRegistry, memory-bridge, diff-classifier,
  # recall-threshold, protocolVersion, SSE, auto-init) are fixed in source.
  agentOrchestratorHome = "${homeDir}/agent-orchestrator";
  cliBin = "${agentOrchestratorHome}/v3/@claude-flow/cli/bin/cli.js";

  serviceScript = pkgs.writeShellScript "agent-orchestrator-service" ''
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

    exec node "${cliBin}" serve start --http --port "''${AGENT_ORCHESTRATOR_PORT:-3456}"
  '';
in
{
  # Custom helper overrides -- only files we've modified.
  # Default helpers are created by `agent-orchestrator init`; these overlay on top.
  home.file.".claude/helpers/router.js" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/agent-orchestrator/router.js";
  };

  home.file.".claude/helpers/agent-enforcement.js" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/agent-orchestrator/agent-enforcement.js";
  };

  home.file.".claude/helpers/post-agent-hook.js" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/agent-orchestrator/post-agent-hook.js";
  };

  # Build agent-orchestrator fork on activation (idempotent).
  home.activation.agentOrchestratorSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    # Prefer nvm node bin; fall back to Nix nodejs_22
    NVM_BIN=""
    for d in "$HOME"/.nvm/versions/node/*/bin; do
      [ -x "$d/node" ] && NVM_BIN="$d" && break
    done
    if [ -n "$NVM_BIN" ]; then
      export PATH="$NVM_BIN:$PATH"
    else
      export PATH="${pkgs.nodejs_22}/bin:$PATH"
    fi
    SETUP_LOG="$HOME/.local/share/agent-orchestrator/setup.log"
    mkdir -p "$(dirname "$SETUP_LOG")"
    echo "--- agent-orchestrator setup $(date -Iseconds) ---" >> "$SETUP_LOG"

    # Install agent-orchestrator deps if needed
    if [ -d "${agentOrchestratorHome}/v3" ] && [ ! -d "${agentOrchestratorHome}/v3/node_modules" ]; then
      echo "Installing agent-orchestrator dependencies..." | tee -a "$SETUP_LOG"
      (cd "${agentOrchestratorHome}/v3" && npm install --legacy-peer-deps 2>&1 | tee -a "$SETUP_LOG") || true
    fi

    # Build CLI if dist is missing
    if [ -d "${agentOrchestratorHome}/v3/@claude-flow/cli" ] && [ ! -d "${agentOrchestratorHome}/v3/@claude-flow/cli/dist" ]; then
      echo "Building agent-orchestrator CLI..." | tee -a "$SETUP_LOG"
      (cd "${agentOrchestratorHome}/v3/@claude-flow/cli" && npx tsc --skipLibCheck 2>&1 | tee -a "$SETUP_LOG") || true
    fi

    # Initialize default helpers if missing
    if [ ! -f "$HOME/.claude/helpers/hook-handler.cjs" ]; then
      echo "Initializing ruflo helpers..." | tee -a "$SETUP_LOG"
      node "${cliBin}" init --minimal --only-claude 2>&1 | tee -a "$SETUP_LOG" || true
    fi

    # Ensure sql.js dependency is installed
    if [ -f "$HOME/.claude/helpers/package.json" ] && [ ! -d "$HOME/.claude/helpers/node_modules" ]; then
      echo "Installing ruflo helper npm dependencies..." | tee -a "$SETUP_LOG"
      (cd "$HOME/.claude/helpers" && npm install --no-audit --no-fund 2>&1 | tee -a "$SETUP_LOG") || true
    fi

    # No upstream bug patches needed -- all fixed in agent-orchestrator source.
  '';

  # Systemd user service for agent-orchestrator HTTP MCP server (Linux only)
  systemd.user.services.agent-orchestrator = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Agent Orchestrator HTTP MCP Server";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${serviceScript}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "AGENT_ORCHESTRATOR_PORT=3456"
        "CLAUDE_FLOW_MODE=v3"
        "CLAUDE_FLOW_HOOKS_ENABLED=true"
        "CLAUDE_FLOW_TOPOLOGY=hierarchical-mesh"
        "CLAUDE_FLOW_MAX_AGENTS=15"
        "CLAUDE_FLOW_MEMORY_BACKEND=hybrid"
        "npm_config_update_notifier=false"
      ];
      StandardOutput = "append:%h/.local/log/agent-orchestrator.log";
      StandardError = "append:%h/.local/log/agent-orchestrator.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
