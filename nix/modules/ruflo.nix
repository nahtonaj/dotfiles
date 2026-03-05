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

  # Install ruflo globally and initialize default helpers if missing.
  home.activation.rufloSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.nodejs_22}/bin:$PATH"

    # Install ruflo if not present
    if ! command -v ruflo &>/dev/null && ! [ -x "$HOME/.nvm/versions/node/$(node -v 2>/dev/null)/bin/ruflo" ]; then
      echo "Installing ruflo..."
      npm install -g ruflo 2>/dev/null || true
    fi

    # Initialize default helpers if missing
    if [ ! -f "$HOME/.claude/helpers/hook-handler.cjs" ]; then
      echo "Initializing ruflo helpers..."
      ruflo init --minimal --only-claude 2>/dev/null || true
    fi

    # Ensure sql.js dependency is installed
    if [ -f "$HOME/.claude/helpers/package.json" ] && [ ! -d "$HOME/.claude/helpers/node_modules" ]; then
      echo "Installing ruflo helper npm dependencies..."
      (cd "$HOME/.claude/helpers" && npm install --no-audit --no-fund 2>/dev/null) || true
    fi
  '';
}
