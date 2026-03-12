# Claude Code — Global Instructions

## Behavioral Rules

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation files unless explicitly requested
- NEVER save working files, text/mds, or tests to the root folder
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files
- Batch all independent operations in a single message for parallelism

## Security Rules

- NEVER hardcode API keys, secrets, or credentials in source files
- NEVER commit .env files or any file containing secrets
- MUST validate user input at system boundaries
- MUST sanitize file paths to prevent directory traversal

## Task Complexity — Scale Effort to Match

Assess every task before starting. Use the minimum ceremony needed.

| Level | Signals | Approach |
|-------|---------|----------|
| **Trivial** | Typo, single-line fix, rename | Direct edit. No agents. |
| **Simple** | 1-3 file change, clear scope | Single agent, no team needed |
| **Medium** | Multi-file, some ambiguity, 2+ concerns | 2-3 agents with `TeamCreate` |
| **Complex** | Cross-module, refactoring, security-sensitive | Full team + routing + topology |

## Automatic Ruflo Triggers

All ruflo tools are accessed as `mcp__ruflo__*`. These triggers are mandatory — run them automatically without being asked.

### On Every Task (all levels)

1. `memory_search` — check for prior patterns relevant to this task
2. `agentdb_pattern-search` — check for reusable solutions
3. Include findings in your approach; skip silently if nothing found

### Before Spawning Any Agent (Simple+)

1. `agentdb_hierarchical-recall` (omit tier) — check for prior context
2. Include recalled context in agent prompt under `## Prior Context`
3. For 2+ prior keys, use `agentdb_context-synthesize` instead of individual recalls

### Before Commits and PRs (all levels)

1. `analyze_diff` + `analyze_diff-risk` — understand changes and risk
2. Risk > 0.7 → warn user, suggest security review before proceeding
3. `analyze_diff-classify` — categorize the change type

### After Completing Any Non-Trivial Task

1. `agentdb_pattern-store` — store reusable pattern with confidence score
2. `memory_store` (namespace: `"patterns"`) — persist cross-session learning
3. `hooks_model-outcome` — record what worked (task type, agent roles, success)

### Code Review Triggers

1. Always run `analyze_diff` + `analyze_diff-risk` first
2. Risk > 0.7 → include `security-auditor` agent
3. Multi-module changes + domain boundary signals → include `ddd-domain-expert`

### DDD Triggers

When task involves restructuring modules, changing data ownership, cross-module coupling, or domain boundary changes → automatically include `ddd-domain-expert` agent.

### Model Routing

Check `[TASK_ROUTING]` output from the UserPromptSubmit hook:
- `[AGENT_BOOSTER_AVAILABLE]` → use Edit tool directly, skip agent
- Low complexity → spawn with `model: "haiku"`
- High complexity / security → spawn with `model: "opus"`

## Execution Model

**This session is the coordinator.** It spawns agents, manages their lifecycle, and synthesizes results. For trivial tasks, the coordinator works directly.

Two layers:
- **Ruflo MCP** (`mcp__ruflo__*`) = coordination, memory, routing, learning, analysis
- **Claude Code** = execution: agents, file ops, bash, git

## Agent Teams (Medium+ only)

Use `TeamCreate` → `Agent` (with `team_name`) → `TeamDelete` for Medium+ tasks. For Simple tasks, bare `Agent` calls are fine.

### Lifecycle

1. `TeamCreate` — name after the task (e.g., `refactor-auth`)
2. Spawn agents with `team_name` and `run_in_background: true` for parallel work
3. Agents store results in agentDB, send key references via `SendMessage`
4. Coordinator recalls from agentDB, synthesizes, responds to user
5. Run "After Completing" triggers above BEFORE teardown
6. `TeamDelete` — one team active at a time; delete before creating another

### Rules

- Batch parallel agent spawns in a single message
- `SendMessage` for coordination signals only — key refs, status (<500 chars)
- For complex tasks, plan first: spawn with `mode: "plan"`, then execute
- Teammates cannot spawn teammates — send spawn request to coordinator

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
```

Key format: `{team}-{agent}-{YYYY-MM-DD}` — store with `tier: "working"`, recall by omitting tier.

## Team Sizing

| Task | Agents |
|------|--------|
| Simple edit | 1 coder |
| Multi-file changes | 2-3 coder + reviewer |
| Code review | 2-3 reviewer + security-auditor (if risk > 0.7) |
| Architecture | 3-4 planner + researcher + coder |
| Refactoring | 3-4 coder + reviewer + tester |

## Ruflo MCP Quick Reference

- **Memory**: `memory_store/search`, `agentdb_hierarchical-store/recall`, `agentdb_context-synthesize`, `agentdb_pattern-store/search`
- **Analysis**: `analyze_diff`, `analyze_diff-risk`, `analyze_diff-classify`, `analyze_diff-stats`
- **Routing**: `hooks_route`, `hooks_model-route`, `coordination_orchestrate`
- **Learning**: `hooks_model-outcome`, `agentdb_pattern-store`, `agentdb_feedback`
- **Lifecycle**: `swarm_init`, `coordination_topology`, `agentdb_session-start/end`
- **Health**: `system_health`, `swarm_health`, `agentdb_health`
