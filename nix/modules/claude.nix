{ config, pkgs, flakePath, ... }:

let
  # ── Dotfiles directory (writable source for all mutable symlinks) ──
  dotfilesDir = "${config.home.homeDirectory}/dotfiles";

  # ── Single source of truth for the Claude agent model ──
  # Change this ONE variable to update the model in ALL agent definitions.
  claudeAgentModel = "claude-opus-4-6";

  # ── Activation script to process agents at switch time ──
  # Injects the model: frontmatter field into every agent .md file,
  # writing results to ~/.claude/agents/ (mutable, not in Nix store).
  # Handles three cases:
  #   1. Frontmatter with existing model: line -> replace it
  #   2. Frontmatter without model: line       -> inject before closing ---
  #   3. No frontmatter at all                 -> prepend one
  processAgentsScript = pkgs.writeShellScript "process-claude-agents" ''
    set -euo pipefail

    src="${dotfilesDir}/.claude/agents"
    dest="$HOME/.claude/agents"
    model="${claudeAgentModel}"

    if [ ! -d "$src" ]; then
      echo "claude.nix: agent source $src not found, skipping" >&2
      exit 0
    fi

    # Clean destination and recreate directory tree
    rm -rf "$dest"
    find "$src" -type d -printf '%P\n' | while IFS= read -r d; do
      mkdir -p "$dest/$d"
    done

    # Process each .md file
    find "$src" -type f -name '*.md' -printf '%P\n' | while IFS= read -r rel; do
      infile="$src/$rel"
      outfile="$dest/$rel"

      if head -1 "$infile" | grep -q '^---$'; then
        # Has YAML frontmatter -- use awk to inject/replace model
        ${pkgs.gawk}/bin/awk -v model="$model" '
          NR==1 && /^---$/ { in_fm=1; print; next }
          in_fm && /^model:/ { print "model: \"" model "\""; replaced=1; next }
          in_fm && /^---$/ {
            if (!replaced) print "model: \"" model "\""
            in_fm=0; print
            next
          }
          { print }
        ' "$infile" > "$outfile"
      else
        # No frontmatter -- prepend one with model field
        printf '%s\n' '---' "model: \"$model\"" '---' > "$outfile"
        cat "$infile" >> "$outfile"
      fi
    done

    # Copy non-.md files verbatim (if any)
    find "$src" -type f ! -name '*.md' -printf '%P\n' | while IFS= read -r rel; do
      cp "$src/$rel" "$dest/$rel"
    done

    echo "claude.nix: processed agents -> $dest"
  '';
in
{
  # --- Direct symlinks (bypass nix store, point straight to dotfiles repo) ---
  home.activation.createClaudeSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.claude/helpers"
    # Mutable bidirectional symlink -- edits on either side reflect immediately.
    rm -f "$HOME/CLAUDE.md"
    ln -sfn "${dotfilesDir}/configs/claude/CLAUDE.md" "$HOME/CLAUDE.md"
    ln -sfn "${dotfilesDir}/configs/claude/settings.json" "$HOME/.claude/settings.json"
    ln -sfn "${dotfilesDir}/.claude/commands" "$HOME/.claude/commands"
    ln -sfn "${dotfilesDir}/.claude/skills" "$HOME/.claude/skills"
    ln -sfn "${dotfilesDir}/.claude/helpers/tmux-pane-title.sh" "$HOME/.claude/helpers/tmux-pane-title.sh"
    ln -sfn "${dotfilesDir}/.claude/helpers/tmux-session-end.sh" "$HOME/.claude/helpers/tmux-session-end.sh"
  '';

  # --- Agents (mutable, processed via activation script) ---
  # Agent .md files need build-time injection (model field), so they
  # cannot be simple symlinks.  Instead of a Nix-store derivation (immutable),
  # an activation script copies and processes them into ~/.claude/agents/ at
  # home-manager switch time, keeping the result writable.
  home.activation.processClaudeAgents = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:$PATH"
    ${processAgentsScript}
  '';

  # --- Packages (node needed for claude-flow) ---
  home.packages = with pkgs; [
    nodejs_22
  ];
}
