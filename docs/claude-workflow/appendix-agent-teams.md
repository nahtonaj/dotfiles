[Back to README](README.md#5-phase-3-execute-with-coordinator--teams)

# Appendix: Agent teams deep dive

This appendix is the canonical reference for agent-teams protocol. The README's section 5 is a summary; when a specific question comes up about how to spawn, coordinate, or shut down, look here.

## The feature flag

Agent teams are experimental. Enable by setting the env var in `~/.claude/settings.json`:

```json
"env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }
```

The `claude-workflow-bootstrap` plugin sets this for you as part of item 5.4(b) of its install checklist.

## The core tools

- `TeamCreate` -- creates a named team. You are the lead by default.
- `TeamDelete` -- tears down a team. Defensive call before `TeamCreate` because `TeamCreate` fails with "Already leading team" if a prior run left one behind.
- `Agent(name, team_name, run_in_background=true)` -- spawns a teammate in the named team. `run_in_background=true` is a HARD RULE; waiting synchronously for an agent defeats parallelism.
- `SendMessage(to, message)` -- routes a message to a named teammate (or `"*"` for broadcast).
- `TaskCreate` / `TaskUpdate` / `TaskList` -- the task board. Status flows via `TaskUpdate`; findings flow via `SendMessage`.

## Spawn sequence

```
TeamDelete (defensive)
  -> TeamCreate(team_name)
  -> TaskCreate(task description)
  -> Agent(name, team_name, run_in_background=true, prompt=<3-section template>)
```

Retry `TeamCreate` once on failure; if it returns "Already leading team", call `TeamDelete` first.

## The 3-section agent prompt template

Every agent prompt has three sections in this order:

```
## PRE_TASK
Pipeline context (if any) is inlined under **Pipeline Context** below.

## TASK
[Pipeline Context, Role, Task, Diff Context]

## POST_TASK
End with a ## RESULTS block:
## RESULTS
- **Status**: completed | partial | blocked
- **Files Changed**: list or "none"
- **Key Findings**: ALL discoveries, decisions, output

RULES: Do NOT spawn agents -- request via coordinator. In git repos, git writes happen only inside your assigned worktree; no branch switching inside a worktree.
```

Pipeline Context is the coordinator's ONLY reliable channel for passing prior agent output into the next agent. Inline the content; do not pass references. See HARD RULE 3 in `configs/claude/CLAUDE.md` for the authoritative spec.

## Shutdown protocol

Lead sends `{type: "shutdown_request"}` via `SendMessage` to each teammate. Teammate replies `{type: "shutdown_response", approve: true}` only after verifying all of:

- No pending or in_progress tasks still owned by them.
- All their edits are saved/committed (worktree clean or handed off).
- All key findings have been sent via `SendMessage`.

If any check fails, the teammate replies `approve: false` with a `reason`, finishes the outstanding work, then signals readiness. Lead retries `shutdown_request`. After every teammate approves, the lead calls `TeamDelete`.

## The three HARD RULE 3 additions from commit `1fb845a`

Commit `1fb845a docs(claude): allow disk-read of team inbox files as SendMessage workaround` added three things to HARD RULE 3 that are load-bearing for correctness:

**1. The reliability caveat.** `SendMessage` is not guaranteed. Claude Code issues #43706, #38932, #42999 can silently drop messages in either direction. Never assume a message went through just because `SendMessage` returned success.

**2. The disk-verification escape hatch.** The persisted inbox files at `~/.claude/teams/{team-name}/inboxes/{teammate-name}.json` (plus the lead's own `team-lead.json`) are the source of truth. Reading them directly to verify delivery is permitted and is not considered polling.

**3. The shutdown verification requirement.** Before concluding a teammate is unresponsive or retrying `shutdown_request`, the lead MUST read both the lead's own inbox file and the teammate's inbox file on disk to check for a persisted `shutdown_response` or findings that in-band delivery missed. Act on whatever is on disk; do not re-send if the response is already persisted.

Prescriptive behavior update that came with the commit: wait for `SendMessage`; do not poll teammates in-band (no status-check DMs, no `TaskList` spam). Disk reads for verification are permitted and are not considered polling.

This is exactly the "protocols are lossy, practices carry you through" thesis from README section 10. The protocol (TeamCreate / SendMessage / TaskUpdate) did not change; the delivery layer did, and HARD RULE 3 absorbed that reality.

Last verified against: Claude Code 2.1.116, claude-mem unavailable, db-agents v1.6.1 (2026-04-21).
