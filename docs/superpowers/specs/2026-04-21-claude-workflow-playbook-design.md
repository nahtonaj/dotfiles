---
title: Claude Workflow Playbook + Bootstrap Plugin -- Design Spec
date: 2026-04-21
status: draft
owner: jon.gao
---

# Claude Workflow Playbook + Bootstrap Plugin

## 1. Summary

We are producing two artifacts from one design pass: a first-person playbook that documents how I run Claude Code day-to-day, and a standalone Claude Code marketplace plugin that bootstraps a fresh install to match. The playbook teaches the Superpowers loop (brainstorm, plan, execute, verify) using coordinator-plus-agent-teams as the mechanics. The plugin ships only the universal, non-personal pieces of that setup so a Databricks teammate can adopt it in minutes without inheriting my machine-specific helpers.

## 2. Goals & Non-goals

Goals:
- Shareable, in-repo playbook that a Databricks engineer can read end-to-end in under 30 minutes.
- A Claude Code plugin, installable from the marketplace, that configures the non-personal parts of my workflow (HARD RULES, env var, recommended plugin list, universal team-cleanup hook).
- Clean separation between universal (shipped) and Jon-specific (documented only) pieces.
- Each artifact can ship independently: doc is useful without the plugin; plugin is useful without reading the full doc.

Non-goals:
- Redistributing my personal hook scripts, dashboard helpers, or Databricks-internal paths.
- Shipping MCP server configuration (teammates get these via internal Databricks tooling).
- Replacing existing team docs or onboarding guides; this is additive.
- Supporting non-Claude-Code agent harnesses.

## 3. Audience & Distribution

Audience is Databricks engineers who already use Claude Code and want a more structured workflow. They are comfortable with CLI plugins and JSON configs. Distribution:
- Playbook: committed under `docs/claude-workflow/` in this dotfiles repo, browsable on GitHub.
- Plugin: published to the Databricks Plugin Marketplace (same target as `plugin-builder`, `bazel-universe`, etc.), installed via `/plugin install claude-workflow-bootstrap`.

## 4. Playbook Doc Design

### 4.1 `docs/claude-workflow/README.md` Outline

Narrative, first-person, nine sections. Target total ~2500 words.

1. Why this doc (~150w). The problem I kept hitting (one-shot prompts that lose context, unverified claims, ad-hoc agent spawning), and what the loop buys you.
2. The loop in one picture (~150w). ASCII diagram: brainstorm -> plan -> execute -> verify -> commit/remember. Names the Superpowers skills and the coordinator role.
3. Phase 1 -- Brainstorm (~250w). Invoking `superpowers:brainstorming`, what good inputs look like, when to stop brainstorming and commit to a spec.
4. Phase 2 -- Plan (~300w). `superpowers:writing-plans`, spec-to-plan boundary, when to split into multiple plans, where specs live (`docs/superpowers/specs/`), where plans live (`docs/superpowers/plans/`).
5. Phase 3 -- Execute with coordinator + teams (~450w). The HARD RULES from `configs/claude/CLAUDE.md`: coordinator stays lightweight, every Agent call uses a team, spawn/coordinate/shutdown lifecycle, Pipeline Context as the only reliable prior-output channel. When to use worktrees.
6. Phase 4 -- Verify (~250w). `superpowers:verification-before-completion`, evidence = file:line + command output, zero tolerance for unverified claims, how I use this in PR comments.
7. Commit, remember, move on (~200w). `commit-commands:commit-push-pr`, claude-mem auto-memory, `pr-review-toolkit:review-pr`.
8. Common failure modes (~250w). Coordinator doing heavy work, agent spawns without team_name, skipping brainstorm, claiming "tests pass" without running them, over-sharing between agents.
9. Minimum viable adoption (~500w). A graduated path: install the bootstrap plugin, try the loop on one small task, add Superpowers, then adopt claude-mem. Each step has a 1-line success check.

### 4.2 Appendix Files

All under `docs/claude-workflow/`, each 200-500 words, each linked from the relevant README section.

- `appendix-claude-md.md` (~450w) -- Annotated walkthrough of the HARD RULES block from `configs/claude/CLAUDE.md`, what each rule defends against, and how to customize for your team.
- `appendix-hooks.md` (~400w) -- Which hooks are universal (claude-mem auto-memory, team-cleanup) vs Jon-specific (status-reporter, dashboard-state, tmux-pane-title). How the plugin handles the universal ones.
- `appendix-skills.md` (~300w) -- The workflow-critical Superpowers skills with a one-line purpose each. Pointer to the superpowers plugin README for the full set.
- `appendix-agent-teams.md` (~500w) -- Deep dive on `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, TeamCreate/SendMessage/TaskUpdate, shutdown protocol, the 3-section agent prompt template, Pipeline Context inlining rules.
- `appendix-mcp.md` (~200w) -- Which MCP servers are relevant (devportal, github, databricks-v2, claude-mem, glean) and where Databricks teammates get config. Explicit note: the plugin does NOT configure MCP.
- `appendix-verification.md` (~300w) -- Concrete examples of verify-before-claim: good evidence vs. bad, how to cite subagent-reported findings, how to retract gracefully.

### 4.3 Tone & Formatting Rules

- First-person ("I", "we"). Direct, opinionated. Short sentences.
- ASCII only, no emoji, no smart quotes.
- Commands in fenced code blocks with language tag.
- File references use `path/from/repo/root:line` form when line is meaningful.
- Every claim that names a Claude Code feature cites the skill or plugin (e.g., "`superpowers:brainstorming`").

### 4.4 Cross-links

- README section N links to its appendix in the first paragraph.
- Every appendix has a "Back to README" link at the top.
- Appendices may cross-link each other when a concept (e.g., HARD RULES) is covered in one canonical place; others link there rather than duplicating.

## 5. Setup Plugin Design

### 5.1 Plugin Identity

- Name: `claude-workflow-bootstrap`. Alternatives considered: `workflow-loop` (too vague), `superpowers-bootstrap` (confuses the Superpowers plugin's own identity), `claude-coord` (unclear intent). `claude-workflow-bootstrap` is explicit about scope (bootstrap only, not a runtime component).
- Version: `0.1.0` at first publish; semver from there.
- Description: "Bootstrap a fresh Claude Code install with an opinionated coordinator + agent-teams workflow."
- Author: Jon Gao (`jon.gao@databricks.com`).

### 5.2 File Layout

```
claude-workflow-bootstrap/
  plugin.json
  marketplace.json
  SKILL.md
  README.md
  scripts/
    install.sh           # idempotent apply
    uninstall.sh         # restore from .bak
    lib/merge-claude-md.sh
    lib/patch-settings.sh
  templates/
    CLAUDE-HARD-RULES.md # the block to merge into ~/.claude/CLAUDE.md
    settings-fragment.json
    team-cleanup.sh      # vendored from dotfiles .claude/helpers/
```

### 5.3 SKILL.md Behavior

The skill is the user-facing entry point. It runs an interactive checklist using `AskUserQuestion`. Each item is independently opt-in and idempotent. Flow:

1. Detect current state: does `~/.claude/CLAUDE.md` exist; does `~/.claude/settings.json` have the env var; does the team-cleanup hook exist; which recommended plugins are installed.
2. Present a checklist of the 5 items in section 5.4; each starts unchecked if already applied (with a note).
3. For each selected item, run the install script fragment; write `.bak` first on any file mutation.
4. Print a final summary of what changed, what was skipped, and how to uninstall.

### 5.4 Configurable Items

a. Install or augment `~/.claude/CLAUDE.md` with a HARD RULES block. Merge strategy: the block is wrapped in `<!-- claude-workflow-bootstrap: begin -->` and `<!-- claude-workflow-bootstrap: end -->` markers. On install, if markers exist the block between them is replaced; if absent the block is appended. Pre-existing content outside the markers is never touched.

b. Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json` under `env`. If the key exists with a different value, ask before overwriting.

c. Recommend (not install) the plugin set: `superpowers`, `claude-mem`, `plugin-builder`, `commit-commands`, `pr-review-toolkit`. The plugin prints the `/plugin install` commands; it does not and cannot install plugins on behalf of the user. This constraint is called out verbatim in the skill output.

d. Install the team-cleanup SessionEnd hook. Writes `~/.claude/helpers/team-cleanup.sh` if absent (never overwrites a differing file without asking), then adds a `SessionEnd` entry to `settings.json` pointing at it. Script source is vendored from `/home/jon.gao/dotfiles/.claude/helpers/team-cleanup.sh`.

e. Offer claude-mem auto-memory integration. Detect whether the claude-mem plugin is present; if yes, this is a no-op (claude-mem wires its own hooks) and the skill says so. If no, the skill recommends installing claude-mem first.

### 5.5 What the Plugin Does NOT Do

- No MCP server configuration. MCPs are an environment concern, not a workflow concern.
- No Jon-specific helpers: `hook-handler.cjs`, `auto-memory-hook.mjs`, `status-reporter.sh`, `auto-approve.sh`, `tmux-pane-title.sh`, `dashboard-state.sh` are explicitly excluded.
- No Databricks-internal paths (nothing under `/home/jon.gao/universe/...`).
- No modifications to `~/.claude/settings.local.json`. Users keep personal overrides there.
- No plugin install actions -- only recommendations.

### 5.6 Idempotency & Safety

- Every file write: create `<path>.bak.<timestamp>` first if the file exists and has not already been backed up by this run.
- Settings.json edits: parse-modify-write via `jq` (a hard dependency declared in `plugin.json`), never string append.
- Hook entries: check for existence by exact script path before insertion.
- Re-running the skill on an already-configured install: every step detects prior state and reports "already applied", exit 0, no mutations.

### 5.7 Uninstall

A `/claude-workflow-bootstrap reset` command (implemented as a SKILL.md sub-mode invoked with `reset`) performs the reverse:
- Remove the marked block from `~/.claude/CLAUDE.md`.
- Unset `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` if and only if this plugin set it (tracked via a sentinel in `~/.claude/.claude-workflow-bootstrap-state.json`).
- Remove the team-cleanup hook entry and delete the vendored script.
- Offer to restore the most recent `.bak` files for each affected file.

The state file is the source of truth for what this plugin touched. Without it, reset is conservative: it removes marker-delimited blocks but does not touch anything else.

## 6. Implementation Phases

Three phases, each independently shippable and reviewable.

### Phase A -- Playbook Doc

Artifacts:
- `docs/claude-workflow/README.md` (all 9 sections, target ~2500 words total).
- All 6 appendix files with final word counts.
- Cross-links verified.

Success criteria:
- A teammate who has never seen my setup can read the README and repeat the loop on a small task.
- Every appendix is reachable from at least one README section and links back.
- No references to unreleased plugin features; doc stands alone.

### Phase B -- Plugin Scaffold

Artifacts:
- `plugin.json`, `marketplace.json` with correct schema (validated by `plugin-builder:plugin-self-review`).
- Empty but valid `SKILL.md` with frontmatter and section scaffolding.
- `templates/` populated with final content.
- `scripts/` with stub install/uninstall that exit 0 and log intent.
- `README.md` for the plugin repo.

Success criteria:
- `plugin-builder:plugin-self-review` passes.
- Plugin can be installed locally from a file path and shows up in `/plugin` list.
- SKILL.md renders a placeholder checklist.

### Phase C -- Interactive Flow + Install Scripts

Artifacts:
- Full SKILL.md interactive flow (detect -> checklist -> apply -> summary).
- `scripts/install.sh` and helpers implement all 5 items from 5.4 with idempotency and `.bak`.
- `scripts/uninstall.sh` implements the 5.7 reset flow.
- State file format documented inline.
- Test fixture: a fresh `~/.claude/` directory structure for dry-run.

Success criteria:
- Install against empty fixture: all 5 items apply cleanly, state file created.
- Install against already-configured fixture: every item reports "already applied", zero mutations.
- Uninstall against configured fixture: state reverts, `.bak` files available, state file removed.
- Install -> uninstall -> install leaves the fixture identical to the first install result.

## 7. Open Questions & Risks

- Final plugin name: confirm `claude-workflow-bootstrap` with user before Phase B. If there is a Databricks naming convention I am unaware of, adjust.
- Marketplace target: confirm the plugin belongs in the same marketplace as `plugin-builder` and `bazel-universe`, or whether it goes in a personal marketplace first.
- Doc-only install path: should the skill offer a "skip hooks, skip env vars, just print the recommendations" mode for users who want the doc content as an interactive walkthrough without any filesystem changes? Small addition; flagging for decision.
- `jq` as hard dependency: acceptable, or should scripts fall back to a pure-bash JSON editor? `jq` is standard on Databricks dev machines.
- Risk: the HARD RULES block references `TeamCreate`/`SendMessage` which depend on the experimental env var. If Anthropic changes the flag name, the doc and the plugin both need a pinned-version warning.
- Risk: claude-mem hook behavior can change between versions. The appendix should pin to the version range I tested against (currently `12.1.6` per `configs/claude/settings.json`).

## 8. Out of Scope

Reiterating the non-goals so a plan writer does not expand scope:
- No MCP configuration.
- No personal helpers, no Databricks-internal scripts, no paths under `/home/jon.gao/universe/`.
- No changes to `settings.local.json`.
- No automated plugin installation on behalf of the user.
- No support for non-Claude-Code harnesses.
- No replacement of existing Databricks onboarding docs -- this is additive.
