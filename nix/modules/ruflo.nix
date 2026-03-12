{ config, pkgs, flakePath, ... }:

{
  # Custom ruflo overrides — only files we've modified.
  # Default helpers are created by `ruflo init`; these overlay on top.
  home.file.".claude/helpers/router.js" = {
    source = "${flakePath}/configs/ruflo/router.js";
  };

  home.file.".claude/helpers/ddd-tracker.sh" = {
    source = "${flakePath}/configs/ruflo/ddd-tracker.sh";
    executable = true;
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
  '';
}
