# Claude Code — Global Instructions

## Rules

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation files unless explicitly requested
- NEVER save working files, text/mds, or tests to the root folder
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files
- NEVER hardcode API keys, secrets, or credentials in source files
- MUST validate user input at system boundaries
- Batch all independent operations in a single message for parallelism

## Coordinator Enforcement

The coordinator session MUST NOT directly invoke these tools:
- `Read`, `Glob`, `Grep` — delegate to agents
- `Edit`, `Write`, `MultiEdit` — delegate to agents
- `Bash` (except `git status`, `git log`, `git diff` for commit prep) — delegate to agents

**The only tools the coordinator may use directly:**
- Ruflo MCP tools (`mcp__ruflo__*`) — for routing, memory, analysis, lifecycle
- `ToolSearch` — to load deferred tool schemas
- `Agent` — to spawn agents
- `TeamCreate` / `TeamDelete` — team lifecycle
- `SendMessage` — coordination signals
- `TaskCreate` / `TaskUpdate` / `TaskList` — task management
- `Skill` — to invoke skills

If you catch yourself about to Read/Edit/Bash, STOP and spawn an agent instead.

## Execution Model

**This session is the coordinator.** It must always remain available for user prompts.

- **Coordinator does**: parse intent, spawn teams, approve permissions, synthesize results, relay to user
- **Coordinator does NOT**: read files, analyze code, run builds, execute commands, or do any direct work
- **Trivial tasks** (single quick command): bare background agent
- **Everything else**: spawn a team

All agents and subagents follow this same structure — they do not do direct work outside their designated role. Subagents must not spawn their own agents; they send spawn requests to the coordinator.

Two layers collaborate:
- **Ruflo MCP** (`mcp__ruflo__*`) — coordination, memory, routing, learning, analysis
- **Claude Code** — execution: teams, agents, file ops, bash, git

## Agent Teams

All non-trivial work goes through teams. No exceptions.

`TeamCreate` → `Agent` (with `team_name`) → `TeamDelete`

### Permission model

Agents inherit the session's pre-approved allowlist from settings.json.

| Work type | Dispatch | Reason |
|-----------|----------|--------|
| Safe ops (reads, analysis, MCP tools) | Background agent in team | No permissions needed |
| Dangerous ops (git, builds, deploys, writes) | Foreground agent in team | Needs user approval |

The coordinator is briefly blocked only when explicit user approval is needed.

### Lifecycle

1. `TeamCreate` — name after the task (e.g., `refactor-auth`)
2. Spawn agents with `team_name` — background for safe ops, foreground for dangerous ops
3. Agents store results in agentDB, send key references via `SendMessage`
4. Coordinator recalls from agentDB, synthesizes, responds to user
5. Run ruflo "after completing" triggers BEFORE teardown
6. `TeamDelete` — one team active at a time; delete before creating another

### Rules

- Batch parallel agent spawns in a single message
- `SendMessage` for coordination signals only — key refs, status (<500 chars)
- For complex tasks, plan first: spawn with `mode: "plan"`, then execute
- Teammates cannot spawn teammates — send spawn request to coordinator

### Sizing

| Task | Agents |
|------|--------|
| Single file edit | 1 coder |
| Multi-file changes | 2-3 coder + reviewer |
| Code review | 2-3 reviewer + security-auditor (if risk > 0.7) |
| Architecture | 3-4 planner + researcher + coder |
| Refactoring | 3-4 coder + reviewer + tester |

## agentDB Protocol

Include in every agent prompt:

```
## agentDB Protocol
- Load tools: ToolSearch query "select:mcp__ruflo__agentdb_hierarchical-store,mcp__ruflo__agentdb_hierarchical-recall,mcp__ruflo__agentdb_pattern-store"
- If prior keys provided, recall context via agentdb_hierarchical-recall (omit tier)
- After work, store results via agentdb_hierarchical-store (key: {team}-{name}-{date}, tier: "working")
- Store reusable patterns via agentdb_pattern-store
- List all agentDB keys in RESULTS section
- Send coordinator only key references via SendMessage
- Do NOT spawn agents yourself — send spawn requests to coordinator
```

Key format: `{team}-{agent}-{YYYY-MM-DD}` — store with `tier: "working"`, recall by omitting tier.

## agentDB Enforcement

1. **Store→Recall cycle**: Agents store results before dependents spawn. Coordinator recalls before spawning next or responding to user.
2. **Recall-Before-Spawn**: Every spawn requires prior `agentdb_hierarchical-recall`. For 2+ keys, try `agentdb_context-synthesize`; if unavailable, recall each key individually and merge in the coordinator prompt.
3. **SendMessage boundary**: Signals only — key refs, status, max 500 chars. Never code or data.

## Pipeline Handoff Protocol

For sequential chains (A → B → C): agent stores in agentDB (`tier: "working"`) → sends key via SendMessage → coordinator recalls to verify → spawns next agent with recalled context. For 3+ agents, use `agentdb_context-synthesize` to merge all prior outputs. Always go through store→recall — never copy raw output or summarize from memory.

## Hierarchical Memory Structure

Store with explicit `tier`; recall by omitting `tier` to search all.

| Tier | Purpose | Lifetime | Use For |
|------|---------|----------|---------|
| `working` | Active task data | Session | Agent results, intermediate state, handoffs |
| `episodic` | Task summaries | Cross-session | Completed outcomes, decisions |
| `semantic` | Extracted knowledge | Permanent | Patterns, architecture, domain rules |

| Tool | When |
|------|------|
| `agentdb_hierarchical-store` | Agent storing results (always specify `tier`) |
| `agentdb_hierarchical-recall` | Retrieving context (omit `tier` to search all) |
| `agentdb_context-synthesize` | Merging 2+ prior agent outputs |
| `agentdb_pattern-store/search` | Reusable patterns (bridges sessions) |
| `memory_store/search` | Cross-session learning (namespace: `"patterns"` only) |

`agentdb_hierarchical-store` is the ONLY inter-agent data mechanism. `memory_store` is cross-session patterns only. At task end, store in both when applicable.

## 4-Phase Task Lifecycle

1. **Route & Plan** (REQUIRED before TeamCreate): `agentdb_pattern-search` + `memory_search` (both MUST run, even if 0 results) → `hooks_route` → `coordination_orchestrate` → `analyze_diff-risk` (risk > 0.7 → security-auditor)
2. **Initialize** (REQUIRED, skip neither): `swarm_init` (topology, maxAgents) → `agentdb_session-start`
3. **Delegate**: `TeamCreate` → every agent prompt MUST include agentDB Protocol block verbatim → store→recall cycle
4. **Complete & Learn** (ALL MUST run before TeamDelete): `agentdb_session-end` → `agentdb_pattern-store` + `memory_store` → `hooks_model-outcome` → `TeamDelete`

## Ruflo Quick Reference

- **Memory**: `memory_store/search`, `agentdb_hierarchical-store/recall`, `agentdb_context-synthesize`, `agentdb_pattern-store/search`
- **Analysis**: `analyze_diff`, `analyze_diff-risk`, `analyze_diff-classify`, `analyze_diff-stats`
- **Routing**: `hooks_route`, `hooks_model-route`, `coordination_orchestrate`
- **Learning**: `hooks_model-outcome`, `agentdb_pattern-store`, `agentdb_feedback`
- **Lifecycle**: `swarm_init`, `coordination_topology`, `agentdb_session-start/end`
- **Health**: `system_health`, `swarm_health`, `agentdb_health`
