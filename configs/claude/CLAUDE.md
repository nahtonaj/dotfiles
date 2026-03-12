# Claude Code — Global Instructions

## Behavioral Rules

- Do what has been asked; nothing more, nothing less
- NEVER create files unless they're absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested
- NEVER save working files, text/mds, or tests to the root folder
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files

## Security Rules

- NEVER hardcode API keys, secrets, or credentials in source files
- NEVER commit .env files or any file containing secrets
- MUST validate user input at system boundaries
- MUST sanitize file paths to prevent directory traversal

## How This Setup Works

Two layers collaborate on every task:

- **Ruflo MCP** = coordination layer: routing (`hooks_route`, `coordination_orchestrate`), memory (`memory_store/search`), agentDB (`agentdb_hierarchical-store/recall`), topology (`swarm_init`, `coordination_topology`), hooks, and learning (`hooks_model-route/outcome`)
- **Claude Code** = execution layer: teams (`TeamCreate`/`TeamDelete`), agents (`Agent` with `team_name`), tasks (`TaskCreate`/`TaskUpdate`), file ops, bash, git
- MCP tools inform spawning decisions; agents do the actual work
- **Teams are ephemeral** — all state is lost on `TeamDelete`. **agentDB persists** across sessions. Always store outputs in agentDB before tearing down a team.

## Using Agent Teams

Lifecycle: `TeamCreate` → `TaskCreate` → `Agent` (with `team_name`) → coordinate → `TeamDelete`

- Every `Agent` call MUST include `team_name` — create a team first, even for single-agent tasks
- Spawn agents with `run_in_background: true` for parallel work
- Use `SendMessage` for coordination signals only — status updates, key references, spawn requests. Never send code or data through it.
- All substantive data flows through agentDB (`agentdb_hierarchical-store` → `agentdb_hierarchical-recall`)
- Persist ALL outputs in agentDB BEFORE calling `TeamDelete`
- For complex tasks, plan first: spawn agents with `mode: "plan"`, store approved plans in agentDB (`plan-{team}-{date}`), then execute
- Batch parallel agent spawns in a single message; batch file ops within agent prompts

## agentDB Discipline

agentDB is the single source of truth for inter-agent data. Teams vanish; agentDB endures.

### 1. Store-Before-Share
Any data a teammate produces that another needs MUST be in agentDB first. Teammates store directly via `agentdb_hierarchical-store` (tier: `"working"`), then send the coordinator a key reference. Coordinator recalls to verify before spawning the next agent.

### 2. Recall-Before-Spawn
Before spawning ANY agent, recall prior context from agentDB. Use `agentdb_hierarchical-recall` (omit `tier` to search all) for single-key lookups, or `agentdb_context-synthesize` when an agent needs context from 2+ prior agents.

### 3. Recall-Before-Responding
Before synthesizing a response to the user, the coordinator recalls from agentDB — never responds from raw agent output.

### Key conventions
- Key format: `{team}-{agent-name}-{date}`
- Store with explicit `tier: "working"`, recall by omitting `tier`
- `memory_store` (namespace: `"patterns"` only) for cross-session learning
- `agentdb_pattern-store` for reusable patterns that bridge sessions
- At end of task, persist to both `memory_store` and `agentdb_pattern-store` when applicable

## Agent Output Format

Agents should end responses with:

```
## RESULTS
- **Status**: completed | partial | blocked
- **Files Changed**: list of files modified
- **Key Findings**: bullet list
- **agentDB Keys Stored**: list of keys stored
```

## Agent agentDB Instructions

Include in every agent prompt:

```
## agentDB Protocol
- Load tools: ToolSearch query "select:mcp__ruflo__agentdb_hierarchical-store,mcp__ruflo__agentdb_hierarchical-recall,mcp__ruflo__agentdb_pattern-store"
- If prior keys provided, recall context via agentdb_hierarchical-recall (omit tier)
- After work, store results via agentdb_hierarchical-store (key: {team}-{name}-{date}, tier: "working")
- Store patterns via agentdb_pattern-store
- List all agentDB keys in RESULTS section
- Send coordinator only key references via SendMessage — never code or data
- Need help? Send spawn request to coordinator — don't spawn agents yourself
```

## Coordination Reference

Guidance for team sizing — not a rigid mandate:

| Task Type | Topology | Agents |
|-----------|----------|--------|
| Simple edit | star | 1 coder |
| Multi-file changes | hierarchical | 2-3 coder + reviewer |
| Code review | mesh | 2-3 reviewer + security-auditor |
| Architecture | hierarchical-mesh | 3-4 planner + researcher + coder |
| Research | mesh | 2-3 researcher |
| Security audit | hierarchical | 2-3 security-auditor + tester |
| Refactoring | hierarchical-mesh | 3-4 coder + reviewer + tester |

For code review tasks, run `analyze_diff` + `analyze_diff-risk` first. If risk > 0.7, include a `security-auditor`.

## Ruflo MCP Quick Reference

- **Routing**: `hooks_route`, `coordination_orchestrate`, `hooks_model-route`
- **Memory**: `memory_store/search` (namespace: `"patterns"`), `agentdb_hierarchical-store/recall`, `agentdb_context-synthesize`
- **Patterns**: `agentdb_pattern-store/search`
- **Lifecycle**: `agentdb_session-start/end`, `coordination_metrics`, `hooks_model-outcome`
- **Swarm**: `swarm_init`, `coordination_topology`, `swarm_health`
- **Analysis**: `analyze_diff`, `analyze_diff-risk`, `analyze_diff-classify`, `analyze_diff-stats`
- **Health**: `system_health`, `swarm_health`, `agentdb_health`
