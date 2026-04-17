{ config, pkgs, lib, flakePath, ... }:

let
  cfg = config.custom.claude;

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

  # Build a derivation that injects `model:` and the ruflo workflow block into
  # every agent .md file at build time, handling three cases:
  #   1. Frontmatter with existing `model:` line → replace it
  #   2. Frontmatter without `model:` line       → inject before closing `---`
  #   3. No frontmatter at all                   → prepend one
  # The ruflo block is injected after the closing `---` but before the body,
  # skipped if the file already contains the marker (idempotent).
  # Agent processing: injects model frontmatter, and optionally the ruflo
  # workflow block (only when custom.claude.injectRufloWorkflow = true).
  injectRuflo = cfg.injectRufloWorkflow;

  processedAgents = pkgs.runCommand "claude-agents" {
    nativeBuildInputs = with pkgs; [ findutils gawk coreutils ];
  } ''
    src="${flakePath}/.claude/agents"
    model="${claudeAgentModel}"
    inject_ruflo="${if injectRuflo then "1" else "0"}"
    ruflo_block="${rufloWorkflowBlock}"

    # Recreate full directory tree
    find "$src" -type d -printf '%P\n' | while IFS= read -r d; do
      mkdir -p "$out/$d"
    done

    # Process each .md file
    find "$src" -type f -name '*.md' -printf '%P\n' | while IFS= read -r rel; do
      infile="$src/$rel"
      outfile="$out/$rel"

      # Check if ruflo block already exists in source (idempotent)
      has_ruflo=0
      grep -q "MANDATORY: Ruflo Workflow Protocol" "$infile" && has_ruflo=1

      if head -1 "$infile" | grep -q '^---$'; then
        # Has YAML frontmatter — use awk to inject/replace model + ruflo block
        ${pkgs.gawk}/bin/awk -v model="$model" -v inject_ruflo="$inject_ruflo" -v has_ruflo="$has_ruflo" -v ruflo_file="$ruflo_block" '
          NR==1 && /^---$/ { in_fm=1; print; next }
          in_fm && /^model:/ { print "model: \"" model "\""; replaced=1; next }
          in_fm && /^---$/ {
            if (!replaced) print "model: \"" model "\""
            in_fm=0; print
            if (inject_ruflo == "1" && !has_ruflo) {
              while ((getline line < ruflo_file) > 0) print line
              close(ruflo_file)
            }
            next
          }
          { print }
        ' "$infile" > "$outfile"
      else
        # No frontmatter — prepend one with model field
        printf '%s\n' '---' "model: \"$model\"" '---' > "$outfile"
        if [ "$inject_ruflo" = "1" ] && [ "$has_ruflo" = "0" ]; then
          cat "$ruflo_block" >> "$outfile"
        fi
        cat "$infile" >> "$outfile"
      fi
    done

    # Copy non-.md files verbatim (if any)
    find "$src" -type f ! -name '*.md' -printf '%P\n' | while IFS= read -r rel; do
      cp "$src/$rel" "$out/$rel"
    done
  '';
in
{
  options.custom.claude.injectRufloWorkflow = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to inject the Ruflo workflow protocol into agent definitions.";
  };

  config = {
  # --- Core config ---
  home.file."CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/claude/${if cfg.injectRufloWorkflow then "CLAUDE" else "CLAUDE-mac"}.md";
  };

  home.file.".claude/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/claude/${if cfg.injectRufloWorkflow then "settings" else "settings-mac"}.json";
  };

  # --- Commands & skills ---
  home.file.".claude/commands" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.claude/commands";
  };

  home.file.".claude/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.claude/skills";
  };

  # --- Agents (model injected at build time; ruflo block only if opted in) ---
  home.file.".claude/agents" = {
    source = processedAgents;
    recursive = true;
  };

  # --- Helpers (tmux integration scripts) ---
  home.file.".claude/helpers/tmux-pane-title.sh" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.claude/helpers/tmux-pane-title.sh";
  };

  home.file.".claude/helpers/tmux-session-end.sh" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.claude/helpers/tmux-session-end.sh";
  };

  # --- Packages (node needed for claude-flow) ---
  home.packages = with pkgs; [
    nodejs_22
  ];
  }; # close config
}
