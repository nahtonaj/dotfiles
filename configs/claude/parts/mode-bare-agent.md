<!-- Mode: bare-agent -- Direct agent delegation without team lifecycle -->

## Allowed Tools

- `mcp__arche__lifecycle_*` -- Session lifecycle tools (session-start, session-close, agent-start, agent-close, memory-start, memory-close). All auto-fire via hooks -- no direct invocation needed. Note: `lifecycle_context-pull` auto-fires via the `UserPromptSubmit` hook (first prompt only) -- do NOT call from SessionStart.
- `mcp__arche__*` -- All other Arche MCP tools (memory, agentDB, coordination, hooks, etc.)
- `Agent` -- Spawn agents (with `isolation: "worktree"`)
- `TaskCreate` / `TaskUpdate` / `TaskGet` / `TaskList` / `TaskOutput` / `TaskStop` -- Task management
- `SendMessage` -- Coordination signals only (< 500 chars, no code). **ALWAYS include `summary`** (5-10 word preview) when message is a string -- Claude Code requires it.
- `AskUserQuestion`, `ToolSearch`, `Skill` -- User interaction and tool discovery
- `EnterPlanMode` / `ExitPlanMode` -- Planning for complex tasks
- `EnterWorktree` / `ExitWorktree` -- Isolated agent work (or pass `isolation: "worktree"` on `Agent`)

---

## Task Lifecycle

**Agents are ephemeral, agentDB persists.** Delegate implementation tasks to agents. Trivial single read-only ops (per Rule #1 exception) may run directly.

### Phase 1: Session Start

`lifecycle_session-start` fires automatically via the SessionStart hook. Coordinator receives `[CONTEXT]` (synthesized memory paragraph) and routing signals via system-reminder -- no manual call needed.

### Phase 2: Delegate

**Ambiguity Gate**: If task intent is unclear or underspecified, use `AskUserQuestion` to clarify before spawning agents. Use `AskUserQuestion` for one focused question per gap; do not over-interview. Skip if task is clearly stated.

**Skills Check**: Before spawning agents, check whether a skill matches the task domain (e.g., `github:*`, `hooks:*`, `swarm:*`, `sparc:*`). If one applies, invoke it via `Skill` to get specialized guidance -- skills override default coordination strategy.

**Per-agent**: `TaskCreate` -> `agentdb_hierarchical-store key="agent-task-{name}@{sessionId}" value="{2-3 sentence task summary}" tier="working"` -> `Agent(name, isolation="worktree", run_in_background=true)` (omit `isolation` outside git repos)

ALL agents use `run_in_background: true`. Coordinator waits for SendMessage notifications, never polls. Teammates self-register (SessionStart hook) and self-persist (Stop hook) -- no manual lifecycle management needed.

**Plan Mode**: Complete Phase 1, recall prior plans via `agentdb_hierarchical-recall`, store approved plan under key `plan-{date}` before execution agents.

**Pipeline handoff**: Agent N stores in agentDB -> coordinator recalls by exact key -> spawns Agent N+1 with recalled context.

**Stop hook extraction**: The Stop hook reads each agent's `## RESULTS` block and **auto-stores the full text** into agentDB working tier under key `{sessionId}-{agentId}`. This is the primary data channel -- the entire RESULTS block is stored verbatim, so agents should put ALL findings, decisions, and output there. Agents do NOT need to call `hierarchical-store` manually for their main findings -- just ensure the `## RESULTS` block is complete and thorough (all fields populated, especially `Key Findings`). For large payloads or pipeline handoffs that exceed what fits in RESULTS, agents may additionally use `hierarchical-store` and list those keys under `agentDB Store Keys` in RESULTS.

**Post-agent verification**: Coordinator MUST recall each agent's `{sessionId}-{agentId}` key from agentDB before using their findings. For sequential pipelines, recall Agent N's key before spawning Agent N+1. For leaf agents, recall the key before responding to the user.

### Phase 3: Close

1. Coordinator receives task-notification when each agent finishes.
2. Stop hook auto-fires `lifecycle_session-close` -- no manual call needed.

---

## Critical Checks (before every tool call)

| # | Check |
|---|-------|
| 1 | Is this a BLOCKED tool? Delegate to an agent -- unless it qualifies as a trivial read-only op (Rule #1 exception: single call, read-only, completes in seconds). |
| 2 | Every `Agent` call has a prior `TaskCreate`? |
| 3 | Agent prompt includes FIRST/LAST STEP blocks? POST_TASK includes complete `## RESULTS` block (Stop hook auto-stores it to agentDB)? |
| 4 | Responding to user? Recalled ALL agents' full findings from agentDB by `{sessionId}-{agentId}` key -- both pipeline and leaf agents. Stop hook auto-persisted complete RESULTS there. Then check `agentDB Store Keys` in the recalled RESULTS -- recall any listed keys for additional context. |
| 5 | Complex task (Plan First? = Yes)? Planned and stored plan before execution? |
| 6 | Relevant skill for this task? Invoke via `Skill` before spawning agents -- skills take precedence over default behavior. |
| 7 | Calling `Agent`? Set `isolation: "worktree"` when the working directory is inside a git repo. Outside git repos, omit `isolation`. Without worktree isolation in git repos, concurrent `git checkout` operations across agents clobber each other, corrupting BUILD files and causing false test failures. |

---

## Failure Recovery

| Failure | Action |
|---------|--------|
| `[CONTEXT]` missing from system-reminder | SessionStart hook may have failed. Proceed without ambient context -- agents self-load what they can via their own SessionStart hooks. |
| Agent times out/crashes | Coordinator fallback-stores any available output, proceeds to next agent. |
| Stop hook / `lifecycle_session-close` fails | Log warning; session data may be lost but task is complete. |
