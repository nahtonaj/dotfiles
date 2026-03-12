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

## Ruflo Triggers

All ruflo tools accessed as `mcp__ruflo__*`. Run automatically — never wait to be asked.

### Every task
- `memory_search` + `agentdb_pattern-search` — check for prior patterns/solutions

### Before spawning agents
- `agentdb_hierarchical-recall` (omit tier) — load prior context into agent prompt
- For 2+ prior keys, use `agentdb_context-synthesize`

### Before commits/PRs
- `analyze_diff` + `analyze_diff-risk` — risk > 0.7 → warn user, include security-auditor
- `analyze_diff-classify` — categorize the change

### After completing work
- `agentdb_pattern-store` — store reusable pattern
- `memory_store` (namespace: `"patterns"`) — cross-session learning
- `hooks_model-outcome` — record what worked

### Model routing
Check `[TASK_ROUTING]` from UserPromptSubmit hook:
- Low complexity → spawn with `model: "haiku"`
- High complexity / security → spawn with `model: "opus"`

## Ruflo Quick Reference

- **Memory**: `memory_store/search`, `agentdb_hierarchical-store/recall`, `agentdb_context-synthesize`, `agentdb_pattern-store/search`
- **Analysis**: `analyze_diff`, `analyze_diff-risk`, `analyze_diff-classify`, `analyze_diff-stats`
- **Routing**: `hooks_route`, `hooks_model-route`, `coordination_orchestrate`
- **Learning**: `hooks_model-outcome`, `agentdb_pattern-store`, `agentdb_feedback`
- **Lifecycle**: `swarm_init`, `coordination_topology`, `agentdb_session-start/end`
- **Health**: `system_health`, `swarm_health`, `agentdb_health`
