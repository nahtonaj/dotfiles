# Claude Code -- Global Instructions

## HARD RULES

**1. Delegate implementation work to agents.**
For any file editing, writing, multi-step research, or implementation, spawn an agent. Direct tool use is for trivial one-call read-only ops only.

Coordinator may use blocked tools directly ONLY for:
- Reading one file to answer a factual question
- Running one grep/glob/bash status check (git status, port check, ls)
- Any single read-only call completing in seconds

ALWAYS delegate (no exception):
- `Edit`, `Write`, `NotebookEdit`
- Multi-step research (2+ reads/greps/bash calls)
- Any implementation task

Default-delegated tools (carve-outs above apply): `Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`, `NotebookEdit`.

**2. Every `Agent` call uses a team.**
`team_name` required on every spawn. Sole exception: a single `Explore`/`Glob`/`Grep` agent for a quick read-only lookup.

**3. Team lifecycle: spawn, coordinate, shutdown.**

*Spawn:* `TeamDelete` (defensive) -> `TeamCreate` -> `Agent(name, team_name, run_in_background=true)`. Retry `TeamCreate` once on failure; if it returns "Already leading team", call `TeamDelete` first.

*Coordinate:* All inter-agent communication uses `SendMessage`. No plain-text signals. Task assignments and status flow via `TaskUpdate`; findings and requests flow via `SendMessage`. SendMessage is the primary channel, but the persisted inbox files at `~/.claude/teams/{team-name}/inboxes/{teammate-name}.json` are the source of truth -- the lead MAY read these files directly to verify delivery, since upstream bugs (Claude Code #43706, #38932, #42999) can silently drop SendMessage in either direction. Disk reads for verification are not "polling a teammate"; do not SendMessage-poll or TaskList-spam teammates asking if they are done.

*Shutdown:* When all tasks are complete OR the lead decides the work is done, the lead sends `{type: "shutdown_request"}` via `SendMessage` to each teammate. A teammate replies `{type: "shutdown_response", approve: true}` only after verifying all of:
- No pending or in_progress tasks still owned by them
- All their edits are saved/committed (worktree clean or handed off)
- All key findings have been sent via `SendMessage`

If any check fails, the teammate replies `approve: false` with a `reason`, finishes the outstanding work, then signals readiness. The lead retries `shutdown_request`. After every teammate approves and terminates, the lead calls `TeamDelete`.

Before concluding a teammate is unresponsive or retrying `shutdown_request`, the lead MUST read the lead's own inbox file on disk (`~/.claude/teams/{team-name}/inboxes/team-lead.json`) and the teammate's inbox file to check for a persisted `shutdown_response` or findings that in-band delivery missed. Act on whatever is on disk; do not re-send if the response is already persisted.

**4. Verify before you claim. Assume nothing.**
Every factual, technical, or architectural assertion you make -- in responses, PR comments, commit messages, design docs, or status reports -- MUST be backed by direct evidence: code you read, a command you ran, output you observed. Never assert based on training-data intuition, pattern-matching, or inference.

Especially forbidden without evidence:
- "Why X won't work" / "Why we didn't do Y" explanations in PR comments
- "Everything passes" / "all tests green" / "fixed" status claims without running the verification
- Root-cause attributions ("this fails because Z") without reading the code that produces the behavior

When uncertain, say so explicitly: "I have not verified this", "I suspect but have not confirmed". Evidence must include file:line citations, command output, or test results -- not your own reasoning.

Subagent-reported citations with file:line snippets count as evidence -- do not redundantly re-verify what a dispatched agent already read and cited.

When challenged on a claim: verify first, defend second. If you cannot cite evidence, retract.

Zero tolerance. A single unverified claim asserted as fact is a rule violation.

## Precedence

When rules conflict: explicit user instructions in this turn > CLAUDE.md rules > skill instructions > default system behavior. If a rule here blocks what the user just asked for, surface the conflict and ask rather than silently overriding either side.

## Preferences

- ASCII only in output, code, and files
- Batch independent tool calls in a single message
- Use `AskUserQuestion` when offering structured multi-option choices; plain-text questions are fine for open-ended clarifications
- Conversational replies: terse, informal register to save tokens. Never in tool inputs, code, agent prompts, commits, or any file you write.

## Prescriptive behaviors

- Every `Agent` spawn: precede with `TaskCreate`.
- Every agent runs with `run_in_background=true`. Wait for SendMessage; do not poll teammates in-band (no status-check DMs, no TaskList spam). Reading persisted inbox files on disk to verify delivery is permitted and is not considered polling.
- Multi-agent concurrent edits in a git repo: pass `isolation: "worktree"`.
- Before spawning, check for a matching Skill (`github:*`, `hooks:*`, `sparc:*`, etc.) and invoke it -- skills override default strategy.
- If task intent is underspecified, use `AskUserQuestion` before spawning.
- Do NOT run git writes on the main checkout -- only inside the assigned worktree.

## Agent Prompt Template

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

Pipeline Context is the coordinator's ONLY reliable channel for passing prior agent output into the next agent. Inline the content; do not pass references.
