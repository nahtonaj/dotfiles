[Back to README](README.md#5-phase-3-execute-with-coordinator--teams)

# Appendix: Helper categorization

My full install has ~40 helper scripts under `.claude/helpers/` plus integration hooks shipped by `db-agents`. For an honest answer to "what does the documented workflow actually require", every helper lands in one of three buckets.

## Bucket 1 -- Required for the documented workflow (installed by v0.1)

Wired into configs/claude/settings.json and load-bearing. All three install automatically when you run the `claude-workflow-bootstrap` plugin.

| Helper | Event(s) wired | settings.json range | How it arrives on disk |
|---|---|---|---|
| `team-cleanup.sh` | `SessionEnd` | configs/claude/settings.json: line 371 | Vendored into the plugin; installed to `~/.claude/helpers/team-cleanup.sh` on plugin apply. |
| `status-reporter.sh` | 11 events: PreToolUse `AskUserQuestion`, PreToolUse `*`, PostToolUse `*`, UserPromptSubmit, SessionStart, SessionEnd, Stop, PreCompact `*`, SubagentStart, SubagentStop, PermissionRequest, Notification `idle_prompt` | configs/claude/settings.json: lines 273-500 | Ships in the `db-agents-*.cjs` release bundle; plugin patches settings.json to reference the bundled path. |
| `auto-approve.sh` | PreToolUse `*` matcher | configs/claude/settings.json: lines 282-295 | Same as status-reporter: ships with db-agents. |

"Relevant only if the user opts into db-agents" applies to status-reporter and auto-approve -- both are db-agents integration hooks. If the user declines the db-agents step in the plugin skill, these entries are not added to settings.json.

## Bucket 2 -- Recommended / optional (documented, no installer support)

Functional but idiosyncratic. Adopt if curious; the plugin has no opinion.

- `hook-handler.cjs` -- my custom routing layer on top of Claude Code hooks. Dispatches to sub-handlers for `pre-bash`, `post-edit`, `route`, and several lifecycle events. Not required by the documented workflow; claude-mem's own hooks plus `team-cleanup.sh` cover the core behaviors.
- `intelligence.cjs`, `learning-service.mjs`, `learning-hooks.sh`, `learning-optimizer.sh`, `pattern-consolidator.sh` -- experimental learning / routing infra.
- `checkpoint-manager.sh`, `standard-checkpoint-hooks.sh` -- optional checkpoint automation.

## Bucket 3 -- Personal / not shareable

Listed for transparency. Plugin has zero opinion on these.

- Custom UI / terminal integrations: `statusline.cjs`, `tmux-pane-title.sh`, `tmux-session-end.sh`.
- Experimental daemons and monitors: the `swarm-*`, `v3-*`, `daemon-manager.sh`, `worker-manager.sh`, `health-monitor.sh`, `perf-worker.sh` families.
- Personal project conventions: `adr-compliance.sh`, `ddd-tracker.sh`, `v3.sh` and relatives.
- One-off automation: `auto-commit.sh`, `github-safe.js`, `github-setup.sh`, `security-scanner.sh`, `guidance-hook*.sh`, `quick-start.sh`, `setup-mcp.sh`.

The plugin's v0.1 skill checklist installs all of Bucket 1. Bucket 2 and Bucket 3 are documented here for transparency but receive no installer support -- now or in future versions.

Last verified against: Claude Code 2.1.116, claude-mem unavailable, db-agents v1.6.1 (2026-04-21).
