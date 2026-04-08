<!-- Mode: agent-teams -- Team-based multi-agent coordination -->

**2. Use Agent Teams for non-trivial operations.**
A **non-trivial op** is one that involves > 2 tool calls OR is expected to take > 1 minute. Non-trivial ops MUST use the full team lifecycle (`TeamDelete` -> `TeamCreate`, `team_name` on every `Agent` call). Lightweight single-agent ops (at most 2 tool calls, < 1 minute) may skip the team lifecycle -- no `TeamCreate`/`TeamDelete` needed, no `team_name` on the `Agent` call.

**3. Complete the 2-step pre-spawn gate for non-trivial ops.**
When spawning a team (non-trivial op): `TeamDelete` (defensive) -> `TeamCreate`. `lifecycle_session-start` fires automatically via SessionStart hook -- do not call it manually. Then spawn teammates with `Agent(name, team_name, prompt)`. Teammates self-register and self-close via their MANDATORY FIRST/LAST STEP blocks. For lightweight ops, skip directly to `Agent(name, prompt)`.

## Allowed Tools

- `mcp__arche__lifecycle_*` -- Session lifecycle tools (session-start, session-close, agent-start, agent-close, memory-start, memory-close). All auto-fire via hooks -- no direct invocation needed. Note: `lifecycle_context-pull` auto-fires via the `UserPromptSubmit` hook (first prompt only) -- do NOT call from SessionStart.
- `mcp__arche__*` -- All other Arche MCP tools (memory, agentDB, coordination, hooks, etc.)
- `Agent` -- Spawn agents (with team lifecycle for non-trivial ops; directly for lightweight ops)
- `TeamCreate` / `TeamDelete` -- Team lifecycle (1:1 with sessions)
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

If spawning a team (non-trivial op):
1. Call `TeamDelete` (defensive -- clears stale team state; ignore errors)
2. Call `TeamCreate` with `team_name` = sessionId. Retry once if it fails.

For lightweight ops, skip these steps.

### Phase 2: Delegate

**Ambiguity Gate**: If task intent is unclear or underspecified, use `AskUserQuestion` to clarify before spawning agents. Use `AskUserQuestion` for one focused question per gap; do not over-interview. Skip if task is clearly stated.

**Skills Check**: Before spawning agents, check whether a skill matches the task domain (e.g., `github:*`, `hooks:*`, `swarm:*`, `sparc:*`). If one applies, invoke it via `Skill` to get specialized guidance -- skills override default coordination strategy.

**Per-agent (non-trivial op / team)**: `TaskCreate` -> `agentdb_hierarchical-store key="agent-task-{name}@{teamName}" value="{2-3 sentence task summary}" tier="working"` -> `Agent(name, team_name=teamName, run_in_background=true)` (omit `isolation` outside git repos)

**Per-agent (lightweight op / no team)**: `TaskCreate` -> `Agent(name, run_in_background=true)` (omit `isolation` outside git repos)

ALL agents use `run_in_background: true`. Coordinator waits for SendMessage notifications, never polls. Teammates self-register (SessionStart hook) and self-persist (Stop hook) -- no manual lifecycle management needed.

**Plan Mode**: Complete Phase 1, recall prior plans via `agentdb_hierarchical-recall`, store approved plan under key `plan-{date}` before execution agents.

**Pipeline handoff**: Agent N stores in agentDB -> coordinator recalls by exact key -> spawns Agent N+1 with recalled context.

**Stop hook extraction**: The Stop hook reads each agent's `## RESULTS` block and **auto-stores the full text** into agentDB working tier under key `{sessionId}-{agentId}`. This is the primary data channel -- the entire RESULTS block is stored verbatim, so agents should put ALL findings, decisions, and output there. Agents do NOT need to call `hierarchical-store` manually for their main findings -- just ensure the `## RESULTS` block is complete and thorough (all fields populated, especially `Key Findings`). For large payloads or pipeline handoffs that exceed what fits in RESULTS, agents may additionally use `hierarchical-store` and list those keys under `agentDB Store Keys` in RESULTS.

**Post-agent verification**: Coordinator MUST recall each agent's `{sessionId}-{agentId}` key from agentDB before using their findings. For sequential pipelines, recall Agent N's key before spawning Agent N+1. For leaf agents, recall the key before responding to the user.

### Shutdown Protocol (team-managed agents only)

**After any agent broadcasts "work complete" (via SendMessage), immediately send `shutdown_request` to that agent.** Do not batch -- send it in the same response turn that you process their completion message. Idle agents waste resources and block session cleanup.

```
SendMessage(to="<agent-name>", message={"type": "shutdown_request", "reason": "Work complete, shutting down."})
```

If multiple agents complete simultaneously, send a `shutdown_request` to each one in the same response turn.

### Phase 3: Close

1. Verify all team-managed agents have been sent `shutdown_request` and acknowledged shutdown.
2. Call `TeamDelete` (only if a team was created)
3. Stop hook auto-fires `lifecycle_session-close` -- no manual call needed.

---

## Critical Checks (before every tool call)

| # | Check |
|---|-------|
| 1 | Is this a BLOCKED tool? Delegate to an agent -- unless it qualifies as a trivial read-only op (Rule #1 exception: single call, read-only, completes in seconds). |
| 2 | Calling `Agent` for a non-trivial op? Completed 2-step gate (TeamDelete, TeamCreate)? SessionStart hook auto-fires `lifecycle_session-start`. Lightweight ops skip the gate. |
| 3 | Every `Agent` call has a prior `TaskCreate`? Non-trivial ops also require `team_name`. |
| 4 | Agent prompt includes FIRST/LAST STEP blocks? POST_TASK includes complete `## RESULTS` block (Stop hook auto-stores it to agentDB)? |
| 5 | Responding to user? Recalled ALL agents' full findings from agentDB by `{sessionId}-{agentId}` key -- both pipeline and leaf agents. Stop hook auto-persisted complete RESULTS there. Then check `agentDB Store Keys` in the recalled RESULTS -- recall any listed keys for additional context. |
| 6 | Complex task (Plan First? = Yes)? Planned and stored plan before execution? |
| 7 | Relevant skill for this task? Invoke via `Skill` before spawning agents -- skills take precedence over default behavior. |
| 8 | Calling `Agent`? Set `isolation: "worktree"` when the working directory is inside a git repo. Outside git repos, omit `isolation`. Without worktree isolation in git repos, concurrent `git checkout` operations across agents clobber each other, corrupting BUILD files and causing false test failures. |

---

## Failure Recovery

| Failure | Action |
|---------|--------|
| `[CONTEXT]` missing from system-reminder | SessionStart hook may have failed. Proceed without ambient context -- agents self-load what they can via their own SessionStart hooks. |
| `TeamCreate` fails | Retry once. If still failing, proceed without team but log warning. |
| Agent times out/crashes | Coordinator fallback-stores any available output, proceeds to next agent. |
| `TeamDelete` fails | Proceed to `lifecycle_session-close`; cleanup is best-effort. |
| `TeamCreate` returns "Already leading team" | Call `TeamDelete` first to clear stale team state, then retry `TeamCreate`. |
| Stop hook / `lifecycle_session-close` fails | Log warning; session data may be lost but task is complete. |

### Agent Prompt: Shutdown Addendum (append to POST_TASK)

When composing agent prompts in agent-teams mode, append this step after POST_TASK step 2:

3. Request shutdown: SendMessage(to="*", message="[your-name] work complete. Coordinator: please send shutdown_request.", summary="Work complete, awaiting shutdown")
   This MUST be your final action. The coordinator will respond with a shutdown_request to terminate your process.

Additional RULES for agent-teams mode: SendMessage is signals only (< 500 chars, no code). Your LAST action is ALWAYS the shutdown request broadcast. Do NOT run git write operations on the main checkout -- work only within your assigned worktree. Do NOT switch branches inside a worktree.
