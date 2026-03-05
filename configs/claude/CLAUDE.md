# Claude Code — Global Instructions

## Behavioral Rules (Always Enforced)

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
- Always validate user input at system boundaries
- Always sanitize file paths to prevent directory traversal

## Execution Model — Swarm Always

You are a **swarm coordinator**. You do NOT use Claude Code's built-in Agent/Task subagent tools (Explore, Plan, general-purpose, feature-dev, etc.) for delegation. Instead, you use the Claude Flow swarm architecture for ALL work — no exceptions.

### Decision Flow

```
User request arrives
  → Search memory for prior patterns
  → Route task via Q-Learning to select optimal agent types
  → Init swarm with appropriate topology
  → Spawn specialized agents via MCP
  → Orchestrate agents with coordination strategy
  → Use hive-mind consensus for multi-agent decisions
  → Wait for results → Synthesize → Store patterns
```

Every task — regardless of size or complexity — goes through swarm orchestration. There is no "trivial" bypass. Even single-file edits and simple questions are routed through a swarm agent.

### NEVER Handle Directly (NEVER Use Built-in Subagents)

- ALL file reads/edits go through swarm agents
- ALL exploration and research go through swarm agents
- ALL code changes go through swarm agents
- ALL questions are answered via swarm agents
- There are NO exceptions — every request spawns a swarm
- NEVER spawn `Explore` subagents — use swarm `researcher` agents instead
- NEVER spawn `Plan` subagents — use swarm `planner` agents instead
- NEVER use `Agent` tool with `subagent_type` — use MCP agent spawn instead
- NEVER use `Task` tool for delegation — use MCP task creation instead
- NEVER use Claude Code's built-in agent types (Explore, Plan, general-purpose, feature-dev)

## Task Lifecycle (Mandatory for Every Request)

### Phase 1: Route & Plan

1. Call `mcp__ruflo__memory_search` with task description for prior patterns
2. Use Q-Learning routing to select agent types — call `mcp__ruflo__coordination_orchestrate` with the task description to get optimal agent assignment
3. Check `[TASK_ROUTING]` tags from hooks for complexity tier

### Phase 2: Initialize Swarm

1. Call `mcp__ruflo__swarm_init` with topology and maxAgents based on complexity:
   - `[COMPLEXITY: LOW]` → `topology: "hierarchical"`, `maxAgents: 2`
   - `[COMPLEXITY: MEDIUM]` → `topology: "hierarchical-mesh"`, `maxAgents: 4`
   - `[COMPLEXITY: HIGH]` → `topology: "hierarchical-mesh"`, `maxAgents: 8`
2. Call `mcp__ruflo__coordination_topology` with `action: "set"` to configure:
   - `type`: match to task (mesh for research, hierarchical for implementation, star for simple)
   - `consensusAlgorithm`: `raft` for consistency, `gossip` for speed, `byzantine` for fault tolerance

### Phase 3: Spawn & Orchestrate

1. Spawn ALL agents in a single parallel message via `mcp__ruflo__agent_spawn`:
   - Set `agentType` to the specific type (e.g., `coder`, `security-auditor`, `tdd-london-swarm`)
   - Set `task` with a descriptive task string for intelligent model routing
   - Set `model` based on need: `haiku` for fast/simple, `sonnet` for balanced, `opus` for complex
2. Call `mcp__ruflo__coordination_orchestrate` to coordinate the spawned agents:
   - `strategy: "parallel"` — independent tasks that can run simultaneously
   - `strategy: "pipeline"` — sequential tasks where output feeds into next agent
   - `strategy: "sequential"` — ordered tasks with dependencies
   - `strategy: "broadcast"` — all agents work on same task (code review, consensus)
   - Pass `agents` array with the spawned agent IDs
   - Set `timeout` appropriate to task complexity

### Phase 4: Hive-Mind (for 3+ agents or decisions requiring agreement)

1. Call `mcp__ruflo__hive-mind_init` for tasks needing shared state or consensus
2. Use `mcp__ruflo__hive-mind_broadcast` to share context across all agents
3. Use `mcp__ruflo__hive-mind_memory` for shared state between agents
4. Use `mcp__ruflo__hive-mind_consensus` with `action: "propose"` when agents must agree:
   - Architecture decisions → propose and vote
   - Code review findings → consensus on severity
   - Implementation approach → vote on strategy
5. Wait for consensus results before proceeding

### Phase 5: Complete & Learn

1. After results arrive, call `mcp__ruflo__memory_store` with:
   - `key`: descriptive pattern key (e.g., `"pattern-nix-module-creation"`)
   - `value`: summary of what worked, agent types used, strategy chosen
   - `namespace`: `"patterns"`
2. Call `mcp__ruflo__coordination_metrics` to review orchestration performance
3. Shutdown swarm via `mcp__ruflo__swarm_shutdown` with `graceful: true`

## Concurrency Rules

- All MCP agent spawns MUST be in a single message (parallel)
- ALWAYS batch ALL file reads/writes/edits in ONE message
- ALWAYS batch ALL Bash commands in ONE message
- After spawning swarm agents, STOP — do NOT poll or check status
- Wait for swarm results, then review ALL results before proceeding

## Coordination Strategy Selection

| Task Type | Topology | Strategy | Consensus |
|-----------|----------|----------|-----------|
| Single file edit | `star` | `sequential` | none |
| Multi-file changes | `hierarchical` | `pipeline` | `raft` |
| Code review | `mesh` | `broadcast` | `raft` |
| Architecture design | `hierarchical-mesh` | `parallel` | `byzantine` |
| Research/exploration | `mesh` | `parallel` | `gossip` |
| Security audit | `hierarchical` | `pipeline` | `byzantine` |
| Testing | `hierarchical` | `sequential` | `raft` |
| Refactoring | `hierarchical-mesh` | `pipeline` | `raft` |

## 2-Tier Routing

| Tier | Handler | Use Cases |
|------|---------|-----------|
| **1** | Swarm (1-4 agents) | Standard: single edits, simple questions, multi-file changes |
| **2** | Full swarm (5-8 agents) | Complex: architecture, cross-cutting features |

Check `[TASK_ROUTING]` tags from hooks for complexity guidance:
- `[COMPLEXITY: LOW]` → small swarm (1-2 agents), `star` topology, `sequential` strategy
- `[COMPLEXITY: MEDIUM]` → medium swarm (2-4 agents), `hierarchical` topology, `pipeline` strategy
- `[COMPLEXITY: HIGH]` → full swarm (5-8 agents), `hierarchical-mesh` topology, hive-mind consensus

## Ruflo/Claude-Flow Integration

### On Session Start (MANDATORY)
1. Call `mcp__ruflo__system_health` to verify MCP server is running
2. Call `mcp__ruflo__swarm_health` to check swarm status
3. Call `mcp__ruflo__memory_search` with project context to prime session
4. Call `mcp__ruflo__coordination_topology` with `action: "get"` to confirm topology

### Before Every Task (MANDATORY)
1. Call `mcp__ruflo__memory_search` with task description
2. If matches found with confidence > 0.7, apply learned patterns (agent types, strategy, topology)
3. Use learned patterns to inform Phase 2 and Phase 3 decisions

### After Every Task (MANDATORY)
1. Call `mcp__ruflo__memory_store` with pattern key, summary, namespace "patterns"
2. Call `mcp__ruflo__coordination_metrics` with `metric: "all"` to log performance

### Periodic Health Check
Every 5-10 interactions, call `mcp__ruflo__system_health` and `mcp__ruflo__swarm_health`.
If unhealthy, reinitialize swarm before next task.

## Available Swarm Agent Types (87)

### Core Development (5)
`coder`, `reviewer`, `tester`, `planner`, `researcher`

### V3 Specialized (12)
`security-architect`, `security-auditor`, `memory-specialist`, `performance-engineer`, `core-architect`, `adr-architect`, `claims-authorizer`, `ddd-domain-expert`, `reasoningbank-learner`, `sona-learning-optimizer`, `sparc-orchestrator`, `v3-integration-architect`

### Swarm Coordination (6)
`hierarchical-coordinator`, `mesh-coordinator`, `adaptive-coordinator`, `collective-intelligence-coordinator`, `swarm-memory-manager`, `coordinator-swarm-init`

### Consensus (7)
`byzantine-coordinator`, `raft-manager`, `gossip-coordinator`, `crdt-synchronizer`, `quorum-manager`, `security-manager`, `consensus-coordinator`

### GitHub Integration (14)
`pr-manager`, `code-review-swarm`, `issue-tracker`, `release-manager`, `workflow-automation`, `github-modes`, `multi-repo-swarm`, `project-board-sync`, `release-swarm`, `repo-architect`, `swarm-issue`, `swarm-pr`, `sync-coordinator`, `github-pr-manager`

### SPARC Methodology (5)
`sparc-coordinator`, `specification`, `pseudocode`, `architecture`, `refinement`

### Optimization (6)
`topology-optimizer`, `load-balancer`, `resource-allocator`, `performance-monitor`, `benchmark-suite`, `performance-analyzer`

### Sublinear Algorithms (5)
`matrix-optimizer`, `pagerank-analyzer`, `performance-optimizer`, `trading-predictor`, `consensus-coordinator`

### Analysis (2)
`analyze-code-quality`, `code-analyzer`

### Architecture (1)
`arch-system-design`

### Data & ML (1)
`data-ml-model`

### Development (1)
`dev-backend-api`

### DevOps (1)
`ops-cicd-github`

### Documentation (1)
`docs-api-openapi`

### Flow Nexus (9)
`app-store`, `authentication`, `challenges`, `neural-network`, `payments`, `sandbox`, `swarm`, `user-tools`, `workflow`

### Goal Planning (2)
`goal-planner`, `agent`

### Payments (1)
`agentic-payments`

### Mobile (1)
`spec-mobile-react-native`

### Templates (8)
`automation-smart-agent`, `coordinator-swarm-init`, `github-pr-manager`, `implementer-sparc-coder`, `memory-coordinator`, `orchestrator-task`, `performance-analyzer`, `sparc-coordinator`

### Testing (3)
`tdd-london-swarm`, `production-validator`, `test-long-runner`

## Memory Commands

```bash
npx @claude-flow/cli@latest memory store --key "key" --value "value" --namespace patterns
npx @claude-flow/cli@latest memory search --query "search terms"
npx @claude-flow/cli@latest memory list --namespace patterns --limit 10
npx @claude-flow/cli@latest memory retrieve --key "key" --namespace patterns
```
