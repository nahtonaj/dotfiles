---
title: Claude Workflow Playbook + Bootstrap Plugin -- Design Spec
date: 2026-04-21
status: draft
owner: jon.gao
---

# Claude Workflow Playbook + Bootstrap Plugin

## 1. Summary

We are producing two artifacts from one design pass: a first-person playbook that documents how I run Claude Code day-to-day, and a standalone marketplace plugin that bootstraps a fresh install to match. The playbook teaches the Superpowers loop (brainstorm, plan, execute, verify) using coordinator-plus-agent-teams as the mechanics. Audience is Databricks engineers, so the plugin ships the workflow-essential, shareable pieces -- including the `db-agents` binary install -- while leaving personal ergonomics out. Required helpers that currently live in my personal dotfiles are categorized and documented in v0.1; automated install is queued for v0.2. The playbook also teaches a durable mindset -- practices persist, protocols do not -- so readers can absorb future Claude Code changes without re-reading.

## 2. Goals & Non-goals

Goals:
- Shareable, in-repo playbook that a Databricks engineer can read end-to-end in under 30 minutes.
- A Claude Code plugin, installable from the marketplace, that configures the workflow defaults (HARD RULES, env var, recommended plugin list, team-cleanup hook) AND installs the `db-agents` compiled binary for teammates who want the dashboard integration.
- Databricks teammates can install the full required toolchain (plugin + db-agents binary) in one pass via the plugin skill; supporting helpers that are required but currently live in my personal dotfiles are documented now, with installation queued for v0.2.
- A three-bucket categorization of every helper script in my setup: required-for-the-documented-workflow, recommended-or-optional, personal-not-shareable. Each bucket has a clear policy on plugin support today and in the future.
- Each artifact can ship independently: doc is useful without the plugin; plugin is useful without reading the full doc.

Non-goals:
- Bundling my personal customizations (tmux pane titles, custom statusline, personal dashboard widgets, learning/intelligence infra) -- these are listed for transparency and not installable via the plugin.
- Auto-configuring MCP servers. The plugin RECOMMENDS the Databricks MCP stack (devportal, databricks-v2, github, glean) and links to install docs, but does not write MCP config on the user's behalf.
- Auto-installing third-party Claude Code plugins on the user's behalf (e.g., superpowers, claude-mem) -- the plugin prints the `/plugin install` commands; the user runs them.
- Replacing existing Databricks onboarding docs or team runbooks; this is additive.
- Supporting non-Claude-Code agent harnesses.

## 3. Audience & Distribution

Audience is Databricks engineers who already use Claude Code and want a more structured workflow. They are comfortable with CLI plugins and JSON configs. Distribution:
- Playbook: committed under `docs/claude-workflow/` in this dotfiles repo, browsable on GitHub.
- Plugin: published to the Databricks Plugin Marketplace (same target as `plugin-builder`, `bazel-universe`, etc.), installed via `/plugin install claude-workflow-bootstrap`.

## 4. Playbook Doc Design

### 4.1 `docs/claude-workflow/README.md` Outline

Narrative, first-person, ten sections. Target total ~2750 words (up from 2500 to accommodate the future-proofing section).

1. Why this doc (~150w). The problem I kept hitting (one-shot prompts that lose context, unverified claims, ad-hoc agent spawning), and what the loop buys you.
2. The loop in one picture (~150w). ASCII diagram: brainstorm -> plan -> execute -> verify -> commit/remember. Names the Superpowers skills and the coordinator role.
3. Phase 1 -- Brainstorm (~250w). Invoking `superpowers:brainstorming`, what good inputs look like, when to stop brainstorming and commit to a spec.
4. Phase 2 -- Plan (~300w). `superpowers:writing-plans`, spec-to-plan boundary, when to split into multiple plans, where specs live (`docs/superpowers/specs/`), where plans live (`docs/superpowers/plans/`).
5. Phase 3 -- Execute with coordinator + teams (~450w). The HARD RULES from `configs/claude/CLAUDE.md`: coordinator stays lightweight, every Agent call uses a team, spawn/coordinate/shutdown lifecycle, Pipeline Context as the only reliable prior-output channel. When to use worktrees. Mentions that running `db-agents` on the side (the web dashboard) is the monitoring surface for long-running agent fleets, with a pointer to `appendix-databricks-tools.md`.
6. Phase 4 -- Verify (~250w). `superpowers:verification-before-completion`, evidence = file:line + command output, zero tolerance for unverified claims, how I use this in PR comments.
7. Commit, remember, move on (~200w). `commit-commands:commit-push-pr`, claude-mem auto-memory, `pr-review-toolkit:review-pr`.
8. Common failure modes (~250w). Coordinator doing heavy work, agent spawns without team_name, skipping brainstorm, claiming "tests pass" without running them, over-sharing between agents.
9. Minimum viable adoption (~500w). A graduated path: install the bootstrap plugin, try the loop on one small task, add Superpowers, then adopt claude-mem. Each step has a 1-line success check.
10. Living with a moving target (~250w). Principle: **practices persist, protocols do not**. Claude Code ships features fast; pinning yourself to a specific tool name dates your workflow. Two concrete applications. (a) Agent teams -- `TeamCreate`/`SendMessage`/`TaskUpdate` is today's surface, with known bugs (Claude Code issues #43706, #38932, #42999 can silently drop `SendMessage` in either direction; HARD RULE 3 in `configs/claude/CLAUDE.md` specifies reading persisted inbox files at `~/.claude/teams/{team-name}/inboxes/*.json` as the disk-based verification channel). The protocol will change. The durable practice -- coordinator delegates heavy work, agents communicate via explicit channels, coordinator verifies from the source of truth -- persists. (b) Memory -- claude-mem is the right choice today, but Claude Code is shipping native memory features that will likely subsume some or all of it. Do not pin the tool; teach the evaluative question ("what do I need to remember across sessions? does native cover it? does claude-mem add value on top?"). Closes with doc-maintenance ground rules: owner (me, until succession), cadence (revisit on any Claude Code minor release that touches agents or memory), versioning (each appendix carries a "Last verified against" footer).

### 4.2 Appendix Files

All under `docs/claude-workflow/`, each 200-500 words, each linked from the relevant README section.

- `appendix-claude-md.md` (~450w) -- Annotated walkthrough of the HARD RULES block from `configs/claude/CLAUDE.md`, what each rule defends against, and how to customize for your team.
- `appendix-helpers.md` (~500w) -- The three-bucket helper categorization (see section 5.5). For each Bucket 1 entry, cite the `configs/claude/settings.json` line range where it is wired, what event it handles, and the v0.2 install plan. Bucket 2 and Bucket 3 listed for transparency.
- `appendix-databricks-tools.md` (~400w) -- Databricks-specific tooling. (1) `db-agents` web dashboard: purpose (per its README at `/home/jon.gao/universe/experimental/richard-liu_data/db-agents/README.md`), canonical install via `gh release download` from `databricks-eng/universe-dev`, Arca-side `node db-agents-*.cjs` launch, SSH port-forward for `localhost:13100`. (2) Databricks MCP recommendations: which servers to enable (`devportal`, `databricks-v2`, `github`, `glean`, `claude-mem`) with pointers to internal docs. Plugin recommends but does not auto-configure MCP.
- `appendix-skills.md` (~300w) -- The workflow-critical Superpowers skills with a one-line purpose each. Pointer to the superpowers plugin README for the full set.
- `appendix-agent-teams.md` (~600w) -- Deep dive on `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, TeamCreate/SendMessage/TaskUpdate, shutdown protocol, the 3-section agent prompt template, Pipeline Context inlining rules. Also documents the **reliability caveat**: SendMessage is not guaranteed (Claude Code issues #43706, #38932, #42999 can silently drop messages in either direction), and the **disk-verification escape hatch** -- the persisted inbox files at `~/.claude/teams/{team-name}/inboxes/{teammate-name}.json` (plus the lead's own `team-lead.json`) are the source of truth, and reading them directly is allowed verification, not polling. Ties back to section 10 of the README: this is exactly the "protocols are lossy, practices carry you through" thesis in action.
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
    install.sh              # idempotent apply
    uninstall.sh            # restore from .bak
    install-db-agents.sh    # gh release download + wrapper
    lib/merge-claude-md.sh
    lib/patch-settings.sh
  templates/
    CLAUDE-HARD-RULES.md    # the block to merge into ~/.claude/CLAUDE.md
    settings-fragment.json
    team-cleanup.sh         # vendored from dotfiles .claude/helpers/
    db-agents-wrapper.sh    # thin launcher for ~/.local/bin/db-agents
```

### 5.3 SKILL.md Behavior

The skill is the user-facing entry point. It runs an interactive checklist using `AskUserQuestion`. Each item is independently opt-in and idempotent. Flow:

1. Detect current state: does `~/.claude/CLAUDE.md` exist; does `~/.claude/settings.json` have the env var; does the team-cleanup hook exist; which recommended plugins are installed; does `db-agents` resolve on PATH; are the recommended MCP servers configured.
2. Present a checklist of the 6 items in section 5.4; each starts unchecked if already applied (with a note).
3. For each selected item, run the install script fragment; write `.bak` first on any file mutation.
4. Print a final summary of what changed, what was skipped, and how to uninstall.

### 5.4 Configurable Items

a. Install or augment `~/.claude/CLAUDE.md` with a HARD RULES block. Merge strategy: the block is wrapped in `<!-- claude-workflow-bootstrap: begin -->` and `<!-- claude-workflow-bootstrap: end -->` markers. On install, if markers exist the block between them is replaced; if absent the block is appended. Pre-existing content outside the markers is never touched.

b. Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json` under `env`. If the key exists with a different value, ask before overwriting.

c. Recommend (not install) the plugin set: `superpowers`, `claude-mem`, `plugin-builder`, `commit-commands`, `pr-review-toolkit`. The plugin prints the `/plugin install` commands; it does not and cannot install plugins on behalf of the user. This constraint is called out verbatim in the skill output.

d. Install the team-cleanup SessionEnd hook. Writes `~/.claude/helpers/team-cleanup.sh` if absent (never overwrites a differing file without asking), then adds a `SessionEnd` entry to `settings.json` pointing at it. Script source is vendored from `/home/jon.gao/dotfiles/.claude/helpers/team-cleanup.sh`.

e. Offer claude-mem auto-memory integration. Detect whether the claude-mem plugin is present; if yes, this is a no-op (claude-mem wires its own hooks) and the skill says so. If no, the skill recommends installing claude-mem first.

f. Install the `db-agents` compiled binary. Flow matches the canonical setup from its README (`/home/jon.gao/universe/experimental/richard-liu_data/db-agents/README.md`):
   - Find the latest tag via `gh release list --repo databricks-eng/universe-dev --limit 20 | grep db-agents | head -1`.
   - `gh release download <tag> --repo databricks-eng/universe-dev --pattern "db-agents-*.cjs"` into `~/.local/share/db-agents/`.
   - Write a wrapper at `~/.local/bin/db-agents` that execs `node ~/.local/share/db-agents/db-agents-*.cjs "$@"`. Warn at launch if `node --version` is below 24 (README pins Node 24).
   - Print a reminder about the SSH `LocalForward 13100 localhost:13100` requirement; do not edit `~/.ssh/config`.
   - Idempotent: skip if the installed artifact matches the latest release; ask before upgrading on version mismatch; fail gracefully with an install hint if `gh` is missing or the user is not authenticated to `databricks-eng/universe-dev`.
   - **Scope note:** binary only. The `status-reporter.sh` and `auto-approve.sh` hooks that wire db-agents into Claude Code are Bucket 1 helpers -- documented, install deferred to v0.2 pending the open question on release bundling (section 7).

### 5.5 Helper Categorization

My current install has ~40 helper scripts in `.claude/helpers/` plus db-agents integration hooks under the universe repo. For the playbook to be honest about what the documented workflow actually depends on, every helper lands in one of three buckets. The playbook's `appendix-helpers.md` carries the same table.

**Bucket 1 -- Required for the documented workflow (document now, install v0.2):**

Wired into `configs/claude/settings.json` and load-bearing for the workflow. v0.1 documents them in `appendix-helpers.md`; v0.2 adds install support.

- `team-cleanup.sh` -- SessionEnd hook that tears down stale agent teams. **Exception:** v0.1 installs this one via item 5.4(d); it is short, dependency-free, already vendored.
- `auto-memory-hook.mjs` -- wired to `Stop` per `configs/claude/settings.json:388-404`; bridges Claude Code stop events into claude-mem's memory pipeline. **Verification needed:** unclear whether still required once the claude-mem plugin wires its own Stop hook. Open question in section 7.
- `status-reporter.sh` -- db-agents integration hook. Reports Claude Code state transitions (idle, running, waiting_input, compacting, permission_request, etc.) to the dashboard. Wired across 11 event types in `configs/claude/settings.json:273-500`. Currently sourced from the universe-repo path, not vendored. Required only if the user runs db-agents.
- `auto-approve.sh` -- db-agents integration hook wired to the PreToolUse `*` matcher (`configs/claude/settings.json:283-295`). Auto-approves tool calls pre-authorized via the dashboard. Same universe-repo sourcing caveat. Required only if running db-agents.

**Bucket 2 -- Recommended / optional (document, no install support planned):**

Functional but idiosyncratic. Teammates can adopt if curious; the plugin does not touch them.

- `hook-handler.cjs` -- my routing layer on top of Claude Code hooks; wired to many events in `configs/claude/settings.json` but not required by the documented workflow (claude-mem's own hooks + `team-cleanup.sh` suffice).
- `intelligence.cjs`, `learning-service.mjs`, the `learning-*` and `pattern-*` scripts -- my experimental learning / routing infra. Not load-bearing.
- `checkpoint-manager.sh`, `standard-checkpoint-hooks.sh` -- optional checkpoint automation.

**Bucket 3 -- Personal / not shareable (listed for transparency, no plugin opinion):**

- Custom UI/terminal integrations: `statusline.cjs`, `tmux-pane-title.sh`, `tmux-session-end.sh`.
- Experimental daemons and monitors: the `swarm-*`, `v3-*`, `daemon-manager.sh`, `worker-manager.sh`, `health-monitor.sh`, `perf-worker.sh` families.
- Personal project conventions: `adr-compliance.sh`, `ddd-tracker.sh`, `v3.sh` and relatives.
- One-off automation: `auto-commit.sh`, `github-safe.js`, `github-setup.sh`, `security-scanner.sh`, `guidance-hook*.sh`, `quick-start.sh`, `setup-mcp.sh`.

`appendix-helpers.md` lists these by filename so teammates can verify nothing sneaks into the plugin, but the plugin has zero opinion on them.

The plugin's v0.1 skill checklist installs Bucket 1's `team-cleanup.sh` (item 5.4.d) and the `db-agents` binary (item 5.4.f). The other Bucket 1 items are documented in `appendix-helpers.md` with enough detail that a motivated user can copy them manually; v0.2 adds automated install for these, gated on resolving the "do the hooks ship in the `.cjs` release bundle" question (section 7).

**What the plugin still does NOT do in v0.1:**
- No auto-install of Bucket 1's db-agents-integration hooks (`status-reporter.sh`, `auto-approve.sh`) or `auto-memory-hook.mjs`. Documented only.
- No installation or configuration of Bucket 2 or Bucket 3 helpers.
- No MCP server auto-configuration (recommendations only, per `appendix-databricks-tools.md`).
- No modifications to `~/.claude/settings.local.json`. Users keep personal overrides there.
- No auto-install of third-party Claude Code plugins on the user's behalf.

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
- Remove `~/.local/bin/db-agents` and `~/.local/share/db-agents/` if this plugin installed them (per state file). The user's running db-agents processes are not killed -- the skill prints a note recommending `pkill -f db-agents` or a browser reload.
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
- `appendix-helpers.md` renders the three-bucket table with each Bucket 1 entry citing the `configs/claude/settings.json` line range where it is wired.
- `appendix-databricks-tools.md` describes the db-agents install flow and lists the recommended MCP servers.
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
- `scripts/install.sh` and helpers implement all 6 items from 5.4 with idempotency and `.bak`.
- `scripts/install-db-agents.sh` implements item 5.4(f): locate latest release tag, download artifact, install wrapper on PATH, idempotent re-runs.
- `scripts/uninstall.sh` implements the 5.7 reset flow.
- State file format documented inline.
- Test fixture: a fresh `~/.claude/` directory structure for dry-run.

Success criteria:
- Install against empty fixture: all 6 items apply cleanly, state file created, `db-agents` resolves on PATH (`command -v db-agents` returns `~/.local/bin/db-agents`).
- Install against already-configured fixture: every item reports "already applied", zero mutations.
- Uninstall against configured fixture: state reverts, `.bak` files available, state file removed, `~/.local/bin/db-agents` removed.
- Install -> uninstall -> install leaves the fixture identical to the first install result.
- db-agents install fails gracefully (clear error, exit non-zero, other items unaffected) when `gh` is missing or the user is not authenticated to `databricks-eng/universe-dev`.
- After install, `which db-agents` resolves to the wrapper script, and the wrapper's `--help` passthrough (or the binary's equivalent) executes without a Node version error on a system with Node 24 on PATH.

## 7. Open Questions & Risks

- Final plugin name: confirm `claude-workflow-bootstrap` with user before Phase B. If there is a Databricks naming convention I am unaware of, adjust.
- Marketplace target: confirm the plugin belongs in the same marketplace as `plugin-builder` and `bazel-universe`, or whether it goes in a personal marketplace first.
- **db-agents hook distribution.** Does the `db-agents-*.cjs` release bundle also ship `status-reporter.sh` and `auto-approve.sh`, or do teammates still need a universe-repo checkout for those hooks? Jon to resolve. Until resolved, v0.2 cannot automate their install. If the universe repo is still required, the plugin writes paths relative to an `$UNIVERSE_REPO` env var rather than hard-coding.
- **Is `auto-memory-hook.mjs` redundant with the claude-mem plugin's own hooks?** Needs verification by reading the claude-mem hooks manifest. If redundant, drop from Bucket 1 and from v0.2 install scope.
- **db-agents auto-start.** v0.1 installs a wrapper only. Should v0.2 optionally ship a systemd/launchd unit? Convenient but opinionated.
- Detection strategy for db-agents: active probe (`command -v db-agents`) or passive prerequisite list. Active probe preferred; adds one detection routine.
- Doc-only mode: should the skill offer "print recommendations, no filesystem writes"? Small addition, flagging for decision.
- `jq` as hard dependency: acceptable, or should scripts fall back to a pure-bash JSON editor? `jq` is standard on Databricks dev machines.
- Risk: the HARD RULES block references `TeamCreate`/`SendMessage` which depend on the experimental env var. If Anthropic changes the flag name, the doc and the plugin both need a pinned-version warning.
- Risk: claude-mem hook behavior can change between versions. The appendix should pin to the version range I tested against (currently `12.1.6` per `configs/claude/settings.json`).
- Risk: db-agents release schema (`gh release list --repo databricks-eng/universe-dev --limit 20 | grep db-agents`) depends on the team keeping the `db-agents` prefix in their tag names. If the naming convention changes, the install script breaks. Mitigation: pin a known-good version and log a warning if newer naming is detected.

## 8. Out of Scope

Reiterating the non-goals so a plan writer does not expand scope:
- No MCP auto-configuration -- recommend only.
- No Bucket 2 or Bucket 3 helpers touched by the skill. Bucket 1 install support beyond `team-cleanup.sh` and the db-agents binary is v0.2 work, not v0.1.
- No changes to `~/.claude/settings.local.json`.
- No auto-install of third-party Claude Code plugins on behalf of the user (the skill prints `/plugin install` commands only).
- Not a replacement for existing Databricks onboarding docs -- this is additive.
- No support for non-Claude-Code harnesses.
