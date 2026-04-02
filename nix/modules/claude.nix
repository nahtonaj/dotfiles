{ config, pkgs, flakePath, ... }:

let
  # ── Dotfiles directory (writable source for all mutable symlinks) ──
  dotfilesDir = "${config.home.homeDirectory}/dotfiles";

  # ── Single source of truth for the Claude agent model ──
  # Change this ONE variable to update the model in ALL agent definitions.
  claudeAgentModel = "claude-opus-4-6";

  # ── Ruflo workflow block injected into every agent definition ──
  rufloWorkflowBlock = pkgs.writeText "ruflo-workflow-block.md" ''

    ## MANDATORY: Ruflo Workflow Protocol

    You MUST follow this protocol for every task. This is non-negotiable.

    ### Before Starting Work
    1. Call `ToolSearch` with query `select:mcp__ruflo__agentdb_hierarchical-store,mcp__ruflo__agentdb_hierarchical-recall,mcp__ruflo__agentdb_pattern-store,mcp__ruflo__agentdb_pattern-search` to load agentDB tools
    2. Call `mcp__ruflo__memory_search` with your task description to find prior patterns
    3. Call `mcp__ruflo__hooks_route` with `{ task: "<your task description>" }` for domain routing
    4. Review matches — if confidence > 0.7, apply the learned pattern (roles, approach, strategy)

    ### After Completing Work
    Store your results DIRECTLY in agentDB (do NOT rely on the coordinator to store for you):
    1. `mcp__ruflo__agentdb_hierarchical-store` with:
       - `key`: `{team}-{agent-name}-{date}` format
       - `value`: your results summary
    2. `mcp__ruflo__agentdb_pattern-store` with any reusable patterns discovered
    3. `mcp__ruflo__memory_store` with:
       - `key`: descriptive pattern key
       - `value`: summary of approach and outcome
       - `namespace`: "patterns"
    4. Send coordinator a coordination signal via `SendMessage` with just the agentDB key reference (e.g., "Findings stored under key: X")

    ### Output Format
    End every response with:
    ```
    ## RESULTS
    - **Status**: completed | partial | blocked
    - **Files Changed**: list of files modified
    - **Key Findings**: bullet list of discoveries
    - **Patterns Discovered**: reusable patterns for storage
    - **agentDB Store Keys**: list of keys stored in agentDB
    - **agentDB Dependencies Consumed**: list of keys recalled (or "none")
    ```
  '';

  # ── Activation script to process agents at switch time ──
  # Injects model: and ruflo workflow block into every agent .md file,
  # writing results to ~/.claude/agents/ (mutable, not in Nix store).
  # Handles three cases:
  #   1. Frontmatter with existing model: line -> replace it
  #   2. Frontmatter without model: line       -> inject before closing ---
  #   3. No frontmatter at all                 -> prepend one
  # The ruflo block is injected after the closing --- but before the body,
  # skipped if the file already contains the marker (idempotent).
  processAgentsScript = pkgs.writeShellScript "process-claude-agents" ''
    set -euo pipefail

    src="${dotfilesDir}/.claude/agents"
    dest="$HOME/.claude/agents"
    model="${claudeAgentModel}"
    ruflo_block="${rufloWorkflowBlock}"

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

      # Check if ruflo block already exists in source (idempotent)
      has_ruflo=0
      grep -q "MANDATORY: Ruflo Workflow Protocol" "$infile" && has_ruflo=1

      if head -1 "$infile" | grep -q '^---$'; then
        # Has YAML frontmatter -- use awk to inject/replace model + ruflo block
        ${pkgs.gawk}/bin/awk -v model="$model" -v has_ruflo="$has_ruflo" -v ruflo_file="$ruflo_block" '
          NR==1 && /^---$/ { in_fm=1; print; next }
          in_fm && /^model:/ { print "model: \"" model "\""; replaced=1; next }
          in_fm && /^---$/ {
            if (!replaced) print "model: \"" model "\""
            in_fm=0; print
            if (!has_ruflo) {
              while ((getline line < ruflo_file) > 0) print line
              close(ruflo_file)
            }
            next
          }
          { print }
        ' "$infile" > "$outfile"
      else
        # No frontmatter -- prepend one with model field + ruflo block
        printf '%s\n' '---' "model: \"$model\"" '---' > "$outfile"
        if [ "$has_ruflo" = "0" ]; then
          cat "$ruflo_block" >> "$outfile"
        fi
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
    ln -sfn "${dotfilesDir}/configs/claude/CLAUDE.md" "$HOME/CLAUDE.md"
    ln -sfn "${dotfilesDir}/configs/claude/settings.json" "$HOME/.claude/settings.json"
    ln -sfn "${dotfilesDir}/.claude/commands" "$HOME/.claude/commands"
    ln -sfn "${dotfilesDir}/.claude/skills" "$HOME/.claude/skills"
    ln -sfn "${dotfilesDir}/.claude/helpers/tmux-pane-title.sh" "$HOME/.claude/helpers/tmux-pane-title.sh"
    ln -sfn "${dotfilesDir}/.claude/helpers/tmux-session-end.sh" "$HOME/.claude/helpers/tmux-session-end.sh"
  '';

  # --- Agents (mutable, processed via activation script) ---
  # Agent .md files need build-time injection (model + ruflo block), so they
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
