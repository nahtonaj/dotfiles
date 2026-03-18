{ config, pkgs, lib, flakePath, ... }:

let
  homeDir = config.home.homeDirectory;

  rufloServiceScript = pkgs.writeShellScript "ruflo-service" ''
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

    # Ensure agentdb controller symlink (upstream bug workaround)
    RUFLO_BIN="$(command -v ruflo 2>/dev/null || true)"
    if [ -n "$RUFLO_BIN" ]; then
      RUFLO_REAL="$(readlink -f "$RUFLO_BIN")"
      RUFLO_ROOT="$(dirname "$(dirname "$RUFLO_REAL")")"
      AGENTDB_DIST="$RUFLO_ROOT/node_modules/agentdb/dist"
      if [ -d "$AGENTDB_DIST/src/controllers" ] && [ ! -e "$AGENTDB_DIST/controllers" ]; then
        ln -s "$AGENTDB_DIST/src/controllers" "$AGENTDB_DIST/controllers" 2>/dev/null || true
      fi
    fi

    exec node "${homeDir}/bin/ruflo-http-server.mjs" --port "''${RUFLO_PORT:-3456}"
  '';
in
{
  # Custom ruflo overrides — only files we've modified.
  # Default helpers are created by `ruflo init`; these overlay on top.
  home.file.".claude/helpers/router.js" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/ruflo/router.js";
  };

  home.file.".claude/helpers/ddd-tracker.sh" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/ruflo/ddd-tracker.sh";
  };

  home.file.".claude/helpers/agent-enforcement.js" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/ruflo/agent-enforcement.js";
  };

  home.file.".claude/helpers/post-agent-hook.js" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/ruflo/post-agent-hook.js";
  };

  # Install ruflo via nvm global (single install location).
  home.activation.rufloSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
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
    RUFLO_LOG="$HOME/.local/share/ruflo/setup.log"
    mkdir -p "$(dirname "$RUFLO_LOG")"
    echo "--- ruflo setup $(date -Iseconds) ---" >> "$RUFLO_LOG"

    # Install ruflo globally if not present
    if ! command -v ruflo &>/dev/null; then
      echo "Installing ruflo..." | tee -a "$RUFLO_LOG"
      npm install -g ruflo 2>&1 | tee -a "$RUFLO_LOG" || true
    fi

    # Initialize default helpers if missing
    if [ ! -f "$HOME/.claude/helpers/hook-handler.cjs" ]; then
      echo "Initializing ruflo helpers..." | tee -a "$RUFLO_LOG"
      ruflo init --minimal --only-claude 2>&1 | tee -a "$RUFLO_LOG" || true
    fi

    # Ensure sql.js dependency is installed
    if [ -f "$HOME/.claude/helpers/package.json" ] && [ ! -d "$HOME/.claude/helpers/node_modules" ]; then
      echo "Installing ruflo helper npm dependencies..." | tee -a "$RUFLO_LOG"
      (cd "$HOME/.claude/helpers" && npm install --no-audit --no-fund 2>&1 | tee -a "$RUFLO_LOG") || true
    fi

    # Patch @claude-flow/memory to export ControllerRegistry (upstream bug)
    ${flakePath}/configs/ruflo/patch-controller-registry.sh 2>&1 | tee -a "$RUFLO_LOG" || true

    # Patch memory-bridge.js pattern-store/search bridge (upstream bug — object vs positional args)
    ${flakePath}/configs/ruflo/patch-memory-bridge.sh 2>&1 | tee -a "$RUFLO_LOG" || true

    # Patch diff-classifier.js ESM/CJS mismatch (upstream bug — require() in ESM module)
    ${flakePath}/configs/ruflo/patch-diff-classifier.sh 2>&1 | tee -a "$RUFLO_LOG" || true

    # Patch recall threshold mismatch (upstream bug — 0.5 default vs 0.3 in search)
    ${flakePath}/configs/ruflo/patch-recall-threshold.sh 2>&1 | tee -a "$RUFLO_LOG" || true
  '';

  # Systemd user service for ruflo HTTP MCP server (Linux only)
  systemd.user.services.ruflo-daemon = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Ruflo HTTP MCP Server";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${rufloServiceScript}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "RUFLO_PORT=3456"
        "CLAUDE_FLOW_MODE=v3"
        "CLAUDE_FLOW_HOOKS_ENABLED=true"
        "CLAUDE_FLOW_TOPOLOGY=hierarchical-mesh"
        "CLAUDE_FLOW_MAX_AGENTS=15"
        "CLAUDE_FLOW_MEMORY_BACKEND=hybrid"
        "npm_config_update_notifier=false"
      ];
      StandardOutput = "append:%h/.local/log/ruflo-daemon.log";
      StandardError = "append:%h/.local/log/ruflo-daemon.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
