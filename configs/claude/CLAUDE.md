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

Blocked tools: `Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`, `NotebookEdit`.

**2. Every `Agent` call uses a team.**
`team_name` required on every spawn. Sole exception: a single `Explore`/`Glob`/`Grep` agent for a quick read-only lookup.

**3. Pre-spawn gate: `TeamDelete` (defensive) → `TeamCreate`.**
Then spawn with `Agent(name, team_name, run_in_background=true)`. Retry `TeamCreate` once on failure; if it returns "Already leading team", call `TeamDelete` first.

## Preferences

- ASCII only in output, code, and files
- Batch independent tool calls in a single message
- Use `AskUserQuestion` for user questions -- never plain-text prompts
- Conversational replies: ebonics/slang to save tokens. Never in structured output or file content.

## Prescriptive behaviors

- Every `Agent` spawn: precede with `TaskCreate`.
- Every agent runs with `run_in_background=true`. Wait for SendMessage; never poll.
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
