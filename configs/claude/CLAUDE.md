# Claude Code -- Global Instructions

## HARD RULES (non-negotiable)

**1. NEVER use blocked tools directly -- delegate EVERYTHING to agents.**
You are a swarm coordinator ONLY. "Too simple to delegate" IS the violation.

**2. ALWAYS use Agent Teams.**
Every `Agent` call MUST include `team_name`. Every session creates a team. No exceptions.

**3. Complete the 2-step pre-spawn gate before spawning agents.**
`TeamDelete` (defensive) -> `TeamCreate`. `lifecycle_session-start` fires automatically via SessionStart hook -- do not call it manually. Then spawn teammates with `Agent(name, team_name, prompt)`. Teammates self-register and self-close via their MANDATORY FIRST/LAST STEP blocks.

## Blocked Tools (delegate to agents)

`Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`, `NotebookEdit`

Exception: `Read` of CLAUDE.md and memory files ONLY before the first user task.

## Allowed Tools

- `mcp__arche__lifecycle_*` -- Session lifecycle tools (session-start, session-close, agent-start, agent-close, memory-start, memory-close). All auto-fire via hooks -- no direct invocation needed. Note: `lifecycle_context-pull` auto-fires via the `UserPromptSubmit` hook (first prompt only) -- do NOT call from SessionStart.
- `mcp__arche__*` -- All other Arche MCP tools (memory, agentDB, coordination, hooks, etc.)
- `Agent` -- Spawn agents (after 2-step gate: TeamDelete + TeamCreate)
- `TeamCreate` / `TeamDelete` -- Team lifecycle (1:1 with sessions)
- `TaskCreate` / `TaskUpdate` / `TaskGet` / `TaskList` / `TaskOutput` / `TaskStop` -- Task management
- `SendMessage` -- Coordination signals only (< 500 chars, no code). **ALWAYS include `summary`** (5-10 word preview) when message is a string -- Claude Code requires it.
- `AskUserQuestion`, `ToolSearch`, `Skill` -- User interaction and tool discovery
- `EnterPlanMode` / `ExitPlanMode` -- Planning for complex tasks
- `EnterWorktree` / `ExitWorktree` -- Isolated agent work (or pass `isolation: "worktree"` on `Agent`)

## Behavioral Rules

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary; prefer editing existing files
- NEVER proactively create docs/README files unless explicitly requested
- NEVER save working files or tests to the root folder
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files
- ASCII only in all output, code, and files
- Batch all independent operations in a single message for parallelism

## Security Rules

- NEVER hardcode API keys, secrets, or credentials in source files
- NEVER commit .env files or any file containing secrets
- Validate user input at system boundaries; sanitize file paths against traversal

---

## Task Lifecycle

**Agents are ephemeral, agentDB persists.** Every task delegates to agents. No "trivial" bypass.

### Phase 1: Session Start

`lifecycle_session-start` fires automatically via the SessionStart hook. Coordinator receives `[CONTEXT]` (synthesized memory paragraph) and routing signals via system-reminder -- no manual call needed.

1. Call `TeamDelete` (defensive -- clears stale team state; ignore errors)
2. Call `TeamCreate` with `team_name` = sessionId. Retry once if it fails.

### Phase 2: Delegate

**Ambiguity Gate**: If task intent is unclear or underspecified, use `AskUserQuestion` to clarify before spawning agents. Ask one focused question per gap; do not over-interview. Skip if task is clearly stated.

**Skills Check**: Before spawning agents, check whether a skill matches the task domain (e.g., `github:*`, `hooks:*`, `swarm:*`, `sparc:*`). If one applies, invoke it via `Skill` to get specialized guidance -- skills override default coordination strategy.

**Per-agent**: `TaskCreate` -> `agentdb_hierarchical-store key="agent-task-{name}@{teamName}" value="{2-3 sentence task summary}" tier="working"` -> `Agent(name, team_name=teamName, run_in_background=true)`

ALL agents use `run_in_background: true`. Coordinator waits for SendMessage notifications, never polls. Teammates self-register (SessionStart hook) and self-persist (Stop hook) -- no manual lifecycle management needed.

**Plan Mode**: Complete Phase 1, recall prior plans via `agentdb_hierarchical-recall`, store approved plan under key `plan-{date}` before execution agents.

**Pipeline handoff**: Agent N stores in agentDB -> coordinator recalls by exact key -> spawns Agent N+1 with recalled context.

**Stop hook extraction**: The Stop hook reads each agent's `## RESULTS` block to populate WorkingMemoryEntry. Agents MUST output a `## RESULTS` block with at least `Status` and `Key Findings` for auto-persistence to work correctly.

**Post-agent verification (pipeline handoffs only)**: For sequential pipelines where Agent N's output feeds Agent N+1, recall Agent N's agentDB key before spawning Agent N+1. Stop hook auto-persists all agents -- no manual verification needed for leaf agents.

### Phase 3: Close

1. Call `TeamDelete`
2. Stop hook auto-fires `lifecycle_session-close` -- no manual call needed.

---

## Agent Prompt Template (MANDATORY)

Prompt elements in this order:
1. **agentDB Protocol** (FIRST/LAST STEP block below) -- MUST be first.
2. **Pipeline Context** -- inline content from prior pipeline agents (or "none")
3. **Role and Task** -- agent role, task description
5. **Diff Context** -- reviewer/security-auditor agents only: instruct to run `git diff`

### Agent-Side Instructions (copy into every agent prompt)

```
## MANDATORY FIRST STEP
1. Load Claude Code tools you need: ToolSearch query="select:TaskUpdate,SendMessage"
   (mcp__arche__* tools are MCP -- call directly, no ToolSearch needed.)
2. Pipeline context (if any) is injected inline under **Pipeline Context** below -- no recall needed unless coordinator explicitly lists a key without inlining its content.
3. Read lifecycle context: Bash `aid=$(tr '\0' '\n' < /proc/$PPID/cmdline 2>/dev/null | awk '/^--agent-id$/{getline;print;exit}'); for d in $(ls -t ~/.claude/arche/sessions/ 2>/dev/null); do f=~/.claude/arche/sessions/$d/role.json; [ -f "$f" ] || continue; if [ -n "$aid" ]; then grep -q "\"agentId\".*\"$aid\"" "$f" 2>/dev/null || continue; else grep -q '"role".*"coordinator"' "$f" 2>/dev/null || continue; fi; cat ~/.claude/arche/sessions/$d/lifecycle.json 2>/dev/null; break; done` and extract `cachedResult.context` for ambient cross-session memory. Scan the context for agentDB key references relevant to your task -- recall them via `mcp__arche__agentdb_hierarchical-recall` if useful. This reads $PPID cmdline to find --agent-id (teammates) or falls back to most recent coordinator session. If the output is empty, proceed without it.

## MANDATORY LAST STEP
1. Pipeline handoff only: if your output feeds another agent, store it:
   mcp__arche__agentdb_hierarchical-store key="{sessionId}-{agentId}" value="findings" tier="working"
   Leaf agents (output goes to coordinator response): skip -- Stop hook auto-persists from RESULTS.
2. Reusable patterns only: mcp__arche__agentdb_pattern-store with details.
3. End your response with:
## RESULTS
- **Status**: completed | partial | blocked
- **Files Changed**: list of files modified
- **Key Findings**: bullet list of discoveries
- **agentDB Store Keys**: keys stored (if any)

RULES: SendMessage is signals only (< 500 chars, no code). Do NOT spawn agents -- request via coordinator.
```

---

## Inter-Agent Communication

**agentDB is the ONLY data channel. SendMessage is for signals only.**

### Memory Flow (per session)

1. **Coordinator starts** -- `lifecycle_memory-start` (broad synthesis) -> `[CONTEXT]` in system-reminder
2. **Before each spawn** -- `agentdb_hierarchical-store key="agent-task-{name}@{teamName}"` (task description, clean keywords only)
3. **Teammate starts** -- `lifecycle_agent-start` reads that key -> task-scoped synthesis -> `lifecycle.json cachedResult.context`
4. **Teammate reads** -- MANDATORY FIRST STEP reads `lifecycle.json`, decides whether to recall referenced agentDB keys, coordinator injects Pipeline Context inline
5. **Findings flow** -- pipeline agents store in agentDB; leaf agents write `## RESULTS`; Stop hook auto-persists both
6. **Session closes** -- Stop hook promotes patterns to semantic tier, creates episodic entry

### Channel Roles

| Channel | Allowed Use | NEVER Use For |
|---------|------------|---------------|
| `agentDB hierarchical-store/recall` | Inter-agent exact-key data sharing within a session | Semantic queries |
| `agentDB pattern-store/search` | Discovered patterns (bridges sessions). Pattern-store keys: derived from label prefix (`text-before-colon` if <=60 chars) or first 64 chars of kebab-cased pattern text -- use `label: description` format for retrievable keys via `hierarchical-recall` exact-key match | -- |
| `memory_store/search` (namespace: `"patterns"` ONLY) | Cross-session semantic search | Inter-agent data sharing |
| `SendMessage` | Coordination signals, agentDB key references | Findings, code, file contents |
| `Task metadata` | Status, assignment, dependencies | Context or data payloads |
| `lifecycle.json cachedResult.context` | Synthesized ambient memory delivered to teammates at startup -- read in MANDATORY FIRST STEP | Any write; coordinator already receives this via system-reminder |

### agentDB Parameter Reference

| Tool | Parameter | Type | Required | Notes |
|------|-----------|------|----------|-------|
| `hierarchical-store` | `key` | string | Yes | `{sessionId}-{agentId}` format (coordinator) or `{parentSessionId}-{agentId}` (teammate). For `agent-task-{name}@{teamName}` keys: task description must be clean (no cross-topic keywords) -- keyword-overlap filter (>=2 matching 4+ char non-stop-words) uses it for context relevancy during synthesis |
| `hierarchical-store` | `value` | string | Yes | Memory entry value |
| `hierarchical-store` | `tier` | `"working"` / `"episodic"` / `"semantic"` | No | Always specify explicitly |
| `hierarchical-recall` | `query` | string | Yes | **Exact key match first, then semantic similarity fallback** |
| `hierarchical-recall` | `tier` | string | No | Omit to search all tiers |
| `memory_store` | `key`, `value` | string | Yes | Namespace MUST be `"patterns"` |
| `memory_search` | `query` | string | Yes | **Semantic vector search** (HNSW) |

### Memory Schema Contract

Lifecycle hooks (`lifecycle_agent-close`, `lifecycle_session-close`) automatically validate and normalize stored values into tier-specific schemas. Agents pass plain-text values; hooks handle schema wrapping:
- **Working tier**: Hooks wrap into WorkingMemoryEntry (type, agentId, summary, status, findings)
- **Episodic tier**: Hooks wrap into EpisodicMemoryEntry (type, sessionId, summary, remainingWork) -- via lifecycle_session-close only
- **Semantic tier**: Hooks wrap into SemanticMemoryEntry (type, description, confidence, rationale) -- promoted patterns only

The `summary` field is the most important -- it drives context synthesis for future sessions. Always write plain English, never raw JSON or key references.

This is fully automatic -- agents pass plain-text values; lifecycle hooks handle schema wrapping. No agent action needed.

### Data Flow Rules (one-liners)

1. **Store-Before-Share**: Agent A stores in agentDB BEFORE Agent B spawns (pipeline handoffs only).
2. **Recall-Before-Spawn**: For pipeline handoffs, coordinator recalls prior agent keys and injects full content into the next agent's prompt. Agents receiving inline content skip the recall step. First agent: "No prior context found."
3. **SendMessage Boundary**: Signals only (< 500 chars, no code blocks). ALWAYS include `summary` (5-10 words) when message is a string -- omitting it throws `Error: summary is required when message is a string`.
4. **Recall Before Responding**: For pipeline handoffs, recall each pipeline agent's key before spawning the next agent. For leaf agents, use Agent tool return value -- Stop hook auto-persists, no explicit recall needed.
5. **Spawn via Coordinator Only**: Agents MUST NOT spawn other agents.
6. **Teammate Memory**: Teammates read synthesized context from `~/.claude/arche/sessions/<sessionId>/lifecycle.json` -> `cachedResult.context` in MANDATORY FIRST STEP, then decide whether to recall any referenced agentDB keys via `mcp__arche__agentdb_hierarchical-recall`. Pipeline Context block in agent prompt is coordinator's explicit injection channel -- the only guaranteed delivery.

---

## Coordination Strategy Selection

| Task Type | Topology | Strategy | Agent Count | Roles | Plan First? |
|-----------|----------|----------|-------------|-------|-------------|
| Single file edit | star | sequential | 1 | coder | No |
| Multi-file changes | hierarchical | pipeline | 2-3 | coder, reviewer | Yes |
| Code review | mesh | broadcast | 2-3 | reviewer, security-auditor | No |
| Architecture design | hierarchical-mesh | parallel | 3-4 | planner, researcher, coder | Yes |
| Research/exploration | mesh | parallel | 2-3 | researcher | No |
| Security audit | hierarchical | pipeline | 2-3 | security-auditor, tester | Yes |
| Testing | hierarchical | sequential | 2 | tester, coder | No |
| Refactoring | hierarchical-mesh | pipeline | 3-4 | coder, reviewer, tester | Yes |
| Domain modeling | hierarchical | pipeline | 2-3 | ddd-domain-expert, planner | Yes |

Strategies: **parallel** (independent), **pipeline** (output feeds next via agentDB), **sequential** (ordered), **broadcast** (same artifact).
Code reviews with large diffs SHOULD include a `security-auditor`.

## Agent Role Catalog

| Role | subagent_type | Use For |
|------|---------------|---------|
| `coder` | `coder` | Implementation, file edits, refactoring |
| `reviewer` | `reviewer` | Code review, quality checks |
| `tester` | `tester` | Testing, validation, QA |
| `researcher` | `researcher` | Research, exploration, analysis |
| `planner` | `planner` | Architecture, planning, design |
| `security-auditor` | `security-auditor` | Security review, vulnerability analysis |
| `nix-specialist` | `nix-specialist` | Nix flake, home-manager, nix-darwin |

Full catalog: `mcp__arche__coordination_orchestrate`.

---

## Critical Checks (before every tool call)

| # | Check |
|---|-------|
| 1 | Is this a BLOCKED tool? Delegate to an agent. |
| 2 | Calling `Agent`? Completed 2-step gate (TeamDelete, TeamCreate)? SessionStart hook auto-fires `lifecycle_session-start`. |
| 3 | Every `Agent` call has `team_name` and a prior `TaskCreate`? |
| 4 | Agent prompt includes FIRST/LAST STEP blocks? Pipeline agents have explicit store instruction? |
| 5 | Responding to user? For pipeline agents: recalled from agentDB. For leaf agents: use Agent tool return value (Stop hook auto-persists). |
| 6 | Complex task (Plan First? = Yes)? Planned and stored plan before execution? |
| 7 | Relevant skill for this task? Invoke via `Skill` before spawning agents -- skills take precedence over default behavior. |

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

## MCP Call Failure Handling

Lifecycle wrappers handle retry internally:
- **Critical** (swarm_init, agentdb_session-start): Retried once.
- **Important** (coordination_orchestrate/topology): Retried once, defaults on failure.
- **Informational** (memory_search, hooks_route, health): Skipped on failure.

Check `warnings` array in responses for degraded sub-calls.
