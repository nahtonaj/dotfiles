# Ruflo + Claude Code Agent Teams — Reference

## 1. Overview

**Ruflo** (alias for `claude-flow`, same `@claude-flow/cli` package) is an MCP-based orchestration layer that turns Claude Code into a multi-agent swarm coordinator. It provides:

- **Routing** — domain-aware task classification and model selection
- **Memory** — cross-session pattern learning with hybrid HNSW-indexed storage
- **AgentDB** — hierarchical persistent store for inter-agent data sharing
- **Coordination** — topology management, strategy selection, and metrics
- **Hooks** — lifecycle events for safety, learning, and session management

MCP tools are accessed as `mcp__ruflo__*` or `mcp__claude-flow__*` (interchangeable). The coordinator delegates ALL work to Agent teammates — it never reads, writes, or edits files directly.

---

## 2. Setup

### MCP Server (`.mcp.json`)

```json
{
  "mcpServers": {
    "claude-flow": {
      "command": "npx",
      "args": ["-y", "@claude-flow/cli@latest", "mcp", "start"],
      "env": {
        "CLAUDE_FLOW_MODE": "v3",
        "CLAUDE_FLOW_HOOKS_ENABLED": "true",
        "CLAUDE_FLOW_TOPOLOGY": "hierarchical-mesh",
        "CLAUDE_FLOW_MAX_AGENTS": "15",
        "CLAUDE_FLOW_MEMORY_BACKEND": "hybrid"
      }
    }
  }
}
```

### Settings Files

| File | Key Settings |
|------|-------------|
| `.claude/settings.local.json` | Enables `["claude-flow", "ruflo"]`, `enableAllProjectMcpServers: true` |
| `~/.claude/settings.local.json` | Enables `["ruflo"]` at user level |
| `.claude/settings.json` | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `CLAUDE_FLOW_V3_ENABLED=true`, hook definitions |

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `CLAUDE_FLOW_MODE` | `v3` | Enable V3 features |
| `CLAUDE_FLOW_HOOKS_ENABLED` | `true` | Enable hook system |
| `CLAUDE_FLOW_TOPOLOGY` | `hierarchical-mesh` | Default topology |
| `CLAUDE_FLOW_MAX_AGENTS` | `15` | Max concurrent agents |
| `CLAUDE_FLOW_MEMORY_BACKEND` | `hybrid` | Memory backend (HNSW + graph) |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | Enable Agent Teams |
| `CLAUDE_FLOW_V3_ENABLED` | `true` | V3 runtime |

---

## 3. Architecture

### Coordinator-Only Model

The main Claude Code instance acts as a **swarm coordinator only**. It NEVER uses work tools (`Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`) directly. All work is delegated to agent teammates via `Agent` with `team_name`.

**Allowed coordinator tools:** `mcp__ruflo__*`, `Agent`, `TeamCreate`/`TeamDelete`, `Task*`, `SendMessage`, `AskUserQuestion`, `ToolSearch`, `Skill`, `EnterPlanMode`/`ExitPlanMode`

### 4-Phase Task Lifecycle

| Phase | Purpose | Key Tools |
|-------|---------|-----------|
| **1. Route & Plan** | Search memory, classify domain, pick strategy | `memory_search`, `hooks_route`, `coordination_orchestrate`, `hooks_model-route` |
| **2. Initialize** | Set up swarm topology and session tracking | `swarm_init`, `coordination_topology`, `agentdb_session-start` |
| **3. Delegate** | Create team, spawn agents, coordinate work | `TeamCreate`, `TaskCreate`, `Agent`, `TaskUpdate`, `SendMessage` |
| **4. Complete & Learn** | Persist patterns, log metrics, tear down | `agentdb_session-end`, `memory_store`, `coordination_metrics`, `hooks_model-outcome`, `TeamDelete` |

```
Phase 1: Route & Plan          Phase 2: Initialize
  memory_search                   swarm_init
  hooks_route                     coordination_topology
  coordination_orchestrate        agentdb_session-start
  hooks_model-route
         |                               |
         v                               v
Phase 3: Delegate               Phase 4: Complete & Learn
  TeamCreate                      agentdb_session-end
  TaskCreate                      memory_store (namespace: "patterns")
  Agent (team_name required)      coordination_metrics
  TaskUpdate / SendMessage        hooks_model-outcome
  agentDB persist                 Shutdown teammates
  TeamDelete                      TeamDelete
```

**Critical constraint:** Only ONE team active per coordinator at a time. Teams MUST be deleted after completion. AgentDB persists across team deletions; team state does not.

**Critical ordering:** Phase 4 persistence (steps 1-4) MUST complete BEFORE team teardown (steps 5-6).

---

## 4. Agent Definitions

### Location and Structure

Agents are defined in `.claude/agents/` with markdown files containing YAML frontmatter:

```markdown
---
model: claude-opus-4-6
name: agent-name
type: developer|analyst|coordinator|validator|architect|security
color: "#FF6B35"
description: Short description
capabilities:
  - self_learning
  - context_enhancement
  - fast_processing
  - smart_coordination
priority: high|medium|critical
hooks:
  pre: |
    init task -> HNSW pattern search -> EWC++ learn -> trajectory tracking
  post: |
    metrics -> pattern store -> task hook -> neural train -> worker dispatch
---

Agent instructions here...
```

### Agent Categories (90+ agents across 14 categories)

| Category | Count | Key Agents |
|----------|-------|-----------|
| `core/` | 5 | coder (#FF6B35, high), researcher (#9B59B6, high), planner (#4ECDC4, high), reviewer (#E74C3C, medium), tester (#F39C12, high) |
| `v3/` | 16 | security-auditor (critical), ddd-domain-expert, memory-specialist, performance-engineer, sparc-orchestrator, aidefence-guardian, adr-architect, claims-authorizer, collective-intelligence-coordinator, injection-analyst, pii-detector, reasoningbank-learner, security-architect, security-architect-aidefence, swarm-memory-manager, v3-integration-architect |
| `github/` | 13 | code-review-swarm, pr-manager, release-swarm, multi-repo-swarm, workflow-automation, github-modes, issue-tracker, project-board-sync, release-manager, repo-architect, swarm-pr, swarm-issue, sync-coordinator |
| `consensus/` | 7 | byzantine-coordinator, raft-manager, crdt-synchronizer, gossip-coordinator, quorum-manager, performance-benchmarker, security-manager |
| `dotfiles/` | 4 | dotfiles-doctor, dotfiles-editor, dotfiles-onboarder, dotfiles-porter |
| `swarm/` | 3 | adaptive-coordinator, hierarchical-coordinator, mesh-coordinator |
| `sublinear/` | 5 | consensus-coordinator, pagerank-analyzer, matrix-optimizer, performance-optimizer, trading-predictor |
| `custom/` | 2 | nix-specialist, test-long-runner |
| `flow-nexus/` | 9 | payments, neural, workflow, sandbox, auth, challenges, swarm, app-store, user-tools |
| Others | 25+ | analysis (3), architecture (2), browser (1), data (2), development (2), devops (3), documentation (2), goal (2), meta (1), optimization (5), payments (1), sona (1), sparc (4), specialized (2), templates (9), testing (2) |

### V3 Hook Lifecycle

**Pre-hook:** init task -> HNSW pattern search -> EWC++ learn from failures -> trajectory tracking
**Post-hook:** metrics -> pattern store (EWC++ consolidation) -> task hook -> neural train (SONA) -> worker dispatch

### Ruflo Role to subagent_type Mapping

| Ruflo Role | `subagent_type` | Use For |
|------------|-----------------|---------|
| coder | `coder` | Implementation, file edits, refactoring |
| reviewer | `reviewer` | Code review, quality checks |
| tester | `tester` | Testing, validation, QA |
| researcher | `researcher` | Research, exploration, analysis |
| planner | `planner` | Architecture, planning, design |
| security-auditor | `security-auditor` | Security review, vulnerability analysis |
| ddd-domain-expert | `ddd-domain-expert` | Domain modeling, bounded contexts |
| nix-specialist | `nix-specialist` | Nix flake, home-manager, nix-darwin |

---

## 5. Skills

Skills are defined in `.claude/skills/` with `SKILL.md` files. **33 skills** across categories:

| Category | Skills |
|----------|--------|
| **AgentDB** (5) | agentdb-learning, agentdb-optimization, agentdb-memory-patterns, agentdb-advanced, agentdb-vector-search |
| **V3** (9) | v3-ddd-architecture, v3-integration-deep, v3-security-overhaul, v3-performance-optimization, v3-core-implementation, v3-memory-unification, v3-swarm-coordination, v3-cli-modernization, v3-mcp-optimization |
| **GitHub** (5) | github-multi-repo, github-code-review, github-project-management, github-release-management, github-workflow-automation |
| **Other** (14) | browser, sparc-methodology, swarm-advanced, swarm-orchestration, hooks-automation, verification-quality, pair-programming, reasoningbank-intelligence, reasoningbank-agentdb, stream-chain, skill-builder |

Skills are invoked via the `Skill` tool (e.g., `/sparc-methodology`, `/github-code-review`).

---

## 6. Hooks

### Hook Events

| Event | Handler | Timeout | Purpose |
|-------|---------|---------|---------|
| **PreToolUse** (Bash) | `hook-handler.cjs pre-bash` | 5s | Command safety validation |
| **PostToolUse** (Write\|Edit\|MultiEdit) | `hook-handler.cjs post-edit` | 10s | Edit learning |
| **UserPromptSubmit** | `hook-handler.cjs route` | 10s | Task routing + `[TASK_ROUTING]` tags |
| **UserPromptSubmit** | `tmux-pane-title.sh` | 15s | Tmux pane title update |
| **SessionStart** | `hook-handler.cjs session-restore` | 15s | Restore prior session context |
| **SessionStart** | `auto-memory-hook.mjs import` | 8s | Import auto-memory |
| **SessionStart** | `hook-handler.cjs daemon-init` | 5s | Initialize daemon workers |
| **SessionEnd** | `hook-handler.cjs session-end` | 10s | Session cleanup |
| **Notification** | StealFocus escape sequence | — | Terminal focus steal |
| **Stop** | `auto-memory-hook.mjs sync` | 10s | Sync auto-memory |
| **Stop** | StealFocus escape sequence | — | Terminal focus steal |
| **PreCompact** (manual/auto) | `hook-handler.cjs compact-*` + `session-end` | — | Pre-compaction cleanup |
| **SubagentStart** | `hook-handler.cjs status` | 3s | Agent status tracking |

### Statusline

`statusline.cjs` provides real-time V3 progress display in the terminal.

### Key Helpers (40+ in `.claude/helpers/`)

| Helper | Purpose |
|--------|---------|
| `hook-handler.cjs` | Central dispatcher for all hook events |
| `router.js` | Keyword-based task routing |
| `session.js` | Session state management |
| `memory.js` | Memory operations |
| `intelligence.cjs` | PageRank-ranked context retrieval |
| `auto-memory-hook.mjs` | Auto-memory import/sync |
| `tmux-pane-title.sh` | Tmux pane title updates |
| `security-scanner.sh` | Security scanning |
| `learning-optimizer.sh` | Learning optimization |
| `swarm-monitor.sh` | Swarm monitoring |
| `daemon-manager.sh` | Daemon lifecycle management |
| `pattern-consolidator.sh` | Pattern consolidation |
| `health-monitor.sh` | Health monitoring |
| `statusline.cjs` | Real-time V3 progress display |
| `metrics-db.mjs` | Metrics database |
| `worker-manager.sh` | Worker management |
| `v3.sh` | V3 integration helpers |

---

## 7. AgentDB

### Tools

| Tool | Parameters | Purpose |
|------|-----------|---------|
| `agentdb_hierarchical-store` | `key` (str, req), `value` (str, req), `tier` (str, opt) | Store data in hierarchical memory |
| `agentdb_hierarchical-recall` | `query` (str, req), `tier` (str, opt), `topK` (num, opt=5) | Recall data (omit tier to search all) |
| `agentdb_context-synthesize` | `query` (str, req), `topK` (num, opt=10) | Synthesize context from multiple entries |
| `agentdb_pattern-store` | `pattern` (str), `type` (str), `confidence` (num) | Store reusable patterns (cross-session) |
| `agentdb_pattern-search` | query params | Search stored patterns |
| `agentdb_session-start` / `session-end` | — | Session lifecycle tracking |
| `agentdb_batch` | operations | Batch multiple operations |
| `agentdb_consolidate` | — | Consolidate memory tiers |
| `agentdb_feedback` | feedback data | Store feedback loop data |
| `agentdb_health` | — | Health check |
| `agentdb_route` / `semantic-route` | query | Semantic routing |
| `agentdb_controllers` | — | Controller management |
| `agentdb_causal-edge` | edge data | Causal graph edge tracking |

### Memory Tiers

| Tier | Purpose | Lifetime |
|------|---------|----------|
| `working` | Active session, inter-agent handoffs | Current session |
| `episodic` | Session-level summaries | Short-term (24h) |
| `semantic` | Long-term patterns and knowledge | Long-term (30d) |

### 5 Mandatory Patterns

#### Pattern 1: Store-Before-Share

Data produced by one agent MUST be in agentDB before the dependent agent is spawned.

```
# Agent stores directly:
mcp__ruflo__agentdb_hierarchical-store({
  key: "fix-config-coder-2026-03-11",
  value: "Fixed nginx.conf line 42: changed worker_connections from 512 to 1024",
  tier: "working"
})

# Agent sends key reference (coordination signal only):
SendMessage("Stored under key: fix-config-coder-2026-03-11")

# Coordinator verifies via recall (omit tier to search all):
mcp__ruflo__agentdb_hierarchical-recall({
  query: "fix-config-coder-2026-03-11"
})

# Recalled data feeds into next agent's prompt
```

#### Pattern 2: Recall-Before-Spawn

ALL agent spawns must be preceded by an `agentdb_hierarchical-recall` call, even for the first agent (picks up prior session context).

```
# Before spawning any agent:
mcp__ruflo__agentdb_hierarchical-recall({
  query: "coder auth endpoint",
  topK: 5
})

# Include results in agent prompt:
# "## Prior agentDB Context\n{recalled data}"
# If nothing found: "## Prior agentDB Context\nNo prior context found."
```

#### Pattern 3: Context-Synthesize for 2+ Keys

When a downstream agent needs context from multiple prior agents, use synthesis instead of individual recalls.

```
# Agent N+1 needs context from agents 1, 2, and 3:
mcp__ruflo__agentdb_context-synthesize({
  query: "reviewer needs context on auth endpoint implementation and test results",
  topK: 10
})

# Include in prompt: "## Prior agentDB Context (Synthesized)\n{synthesized output}"
```

#### Pattern 4: Key Format Convention

```
{team}-{agent-name}-{date}

Examples:
  fix-config-coder-2026-03-11
  refactor-auth-researcher-2026-03-11
  review-pr42-security-auditor-2026-03-11
```

#### Pattern 5: Tier Consistency

- **Store** with explicit `tier: "working"` (always)
- **Recall** by omitting `tier` (searches all tiers, prevents mismatches)
- Only specify `tier` in recall when intentionally filtering to a specific tier

---

## 8. Memory and Learning

### Two Persistence Systems

| System | Tool | Namespace | Scope | Use For |
|--------|------|-----------|-------|---------|
| **memory_store** | `mcp__ruflo__memory_store` | `"patterns"` ONLY | Cross-session | Patterns learned from completed tasks |
| **agentdb_pattern-store** | `mcp__ruflo__agentdb_pattern-store` | — | Cross-session (ReasoningBank) | Reusable patterns with confidence scores |

**End-of-task rule:** Store in BOTH systems when applicable. `memory_store` is NEVER used for inter-agent data sharing (use `agentdb_hierarchical-store` for that).

### Channel Delineation

| Channel | Allowed Use | NEVER Use For |
|---------|------------|---------------|
| `agentdb_hierarchical-store/recall` | Inter-agent data sharing within a session | — |
| `agentdb_pattern-store/search` | Discovered patterns (bridges sessions) | — |
| `memory_store/search` (`"patterns"` ONLY) | Cross-session pattern learning | Inter-agent context |
| `SendMessage` | Coordination signals only (<500 chars) | Findings, code, data |

### Backend Configuration

```json
{
  "memory": {
    "backend": "hybrid",
    "enableHNSW": true,
    "learningBridge": { "enabled": true },
    "memoryGraph": { "enabled": true },
    "agentScopes": { "enabled": true }
  },
  "learning": {
    "enabled": true,
    "autoTrain": true,
    "patterns": ["coordination", "optimization", "prediction"],
    "retention": { "shortTerm": "24h", "longTerm": "30d" }
  }
}
```

### Local Data Files

| Path | Content |
|------|---------|
| `.claude-flow/data/auto-memory-store.json` | Auto-memory persistent store |
| `.claude-flow/data/graph-state.json` | Memory graph state |
| `.claude-flow/data/ranked-context.json` | PageRank-ranked context |
| `.claude-flow/data/pending-insights.jsonl` | Pending insights queue |
| `.claude-flow/sessions/current.json` | Current session state |

---

## 9. Team Workflow

### Full Lifecycle (Every Task)

```
# 1. Create team
TeamCreate({ team_name: "fix-auth", description: "Fix authentication bug" })

# 2. Create task
TaskCreate({ subject: "Fix JWT validation", description: "..." })

# 3. Spawn teammate (with agentDB Protocol in prompt)
Agent({
  subagent_type: "coder",
  name: "auth-fixer",
  team_name: "fix-auth",
  prompt: "You are a **coder**. Fix JWT validation in auth.ts...\n\n## agentDB Protocol (MANDATORY)\n..."
})

# 4. Track progress
TaskUpdate({ task_id: "...", status: "in_progress" })

# 5. Coordinate (signals only, <500 chars)
SendMessage({ to: "auth-fixer", type: "message", content: "Priority: fix token expiry check first" })

# 6. Verify agentDB persistence
mcp__ruflo__agentdb_hierarchical-recall({ query: "fix-auth-auth-fixer-2026-03-11" })

# 7. Persist patterns (BEFORE teardown)
mcp__ruflo__agentdb_session-end()
mcp__ruflo__memory_store({ key: "pattern-jwt-fix", value: "...", namespace: "patterns" })
mcp__ruflo__agentdb_pattern-store({ pattern: "...", type: "bug-fix", confidence: 0.9 })
mcp__ruflo__coordination_metrics({ metric: "all" })
mcp__ruflo__hooks_model-outcome({ taskType: "bug-fix", roles: ["coder"], success: true })

# 8. Shut down teammates
SendMessage({ to: "auth-fixer", type: "shutdown_request" })

# 9. Tear down team (AFTER all persistence)
TeamDelete({ team_name: "fix-auth" })
```

### Pipeline Handoff Protocol

For sequential multi-agent tasks where each agent's output feeds the next:

```
Agent N stores:       agentdb_hierarchical-store(key: "{team}-{agent-N}-{date}", tier: "working")
Agent N signals:      SendMessage("Stored under key: {team}-{agent-N}-{date}")
Coordinator recalls:  agentdb_hierarchical-recall(query: key)
Coordinator spawns:   Agent N+1 with recalled context in prompt
```

For 3+ agents where Agent N+1 needs all prior context:

```
Coordinator synthesizes: agentdb_context-synthesize(query: "Agent N+1 role description")
Coordinator spawns:      Agent N+1 with synthesized context
```

### Constraints

- **Single team per coordinator** — delete current team before creating another
- **Bare Agent calls are violations** — always include `team_name`
- **agentDB persistence before TeamDelete** — team state is lost permanently on deletion
- **SendMessage is coordination only** — no code, no findings, no data (<500 chars)
- **Teammates cannot spawn teammates** — send spawn request to coordinator via SendMessage

### Coordination Strategies

| Strategy | Behavior |
|----------|----------|
| `parallel` | All teammates spawned at once, independent tasks |
| `pipeline` | Each teammate's output feeds the next via agentDB handoff |
| `sequential` | One teammate at a time; ordering-based dependencies |
| `broadcast` | Multiple teammates work on same artifact (review/consensus) |

### Topologies

| Topology | Shape |
|----------|-------|
| `star` | 1 lead teammate handles task |
| `hierarchical` | Coordinator delegates sub-tasks to teammates |
| `mesh` | Peers work independently on related pieces |
| `hierarchical-mesh` | Coordinator coordinates sub-teams of peers |

### Agent Teams Configuration

```json
{
  "agentTeams": {
    "enabled": true,
    "teammateMode": "auto",
    "taskListEnabled": true,
    "mailboxEnabled": true,
    "coordination": {
      "autoAssignOnIdle": true,
      "trainPatternsOnComplete": true,
      "notifyLeadOnComplete": true
    }
  }
}
```

### Daemon Workers (10)

| Worker | Interval | Purpose |
|--------|----------|---------|
| map | — | Codebase mapping |
| audit | 1h | Code auditing |
| optimize | 30m | Optimization |
| consolidate | 2h | Memory consolidation |
| testgaps | — | Test gap detection |
| ultralearn | 1h | Ultra learning |
| deepdive | 4h | Deep analysis |
| document | 1h | Documentation |
| refactor | — | Refactoring |
| benchmark | — | Benchmarking |

---

## 10. Commands

90+ commands in `.claude/commands/` organized by category:

| Category | Key Commands |
|----------|-------------|
| **Top-level** | claude-flow-help, claude-flow-swarm, claude-flow-memory |
| **Analysis** | bottleneck-detect, performance-bottlenecks, performance-report, token-usage, token-efficiency |
| **Automation** | auto-agent, smart-spawn, session-memory, workflow-select, self-healing, smart-agents |
| **GitHub** | code-review, code-review-swarm, github-swarm, issue-triage, repo-analyze, pr-enhance, multi-repo-swarm, release-swarm, swarm-pr, swarm-issue, workflow-automation, pr-manager, release-manager, repo-architect, github-modes, issue-tracker, sync-coordinator, project-board-sync |
| **Hooks** | pre-edit, post-edit, post-task, session-end, pre-task, overview, setup |
| **Monitoring** | agent-metrics, real-time-view, swarm-monitor, agents, status |
| **Optimization** | topology-optimize, cache-manage, parallel-execute, auto-topology, parallel-execution |
| **SPARC** | architect, coder, tester, reviewer, orchestrator, debugger, designer, optimizer, documenter, tdd, memory-manager, swarm-coordinator, innovator, researcher, batch-executor, workflow-manager, analyzer (20+ modes) |

---

## 11. Usage Examples

### Example 1: Simple Single-File Edit (Star Topology)

```
# Phase 1: Route & Plan
mcp__ruflo__memory_search({ query: "fix config parsing" })
mcp__ruflo__hooks_route({ input: "fix config parsing bug in parser.ts" })
mcp__ruflo__coordination_orchestrate({ task: "fix config parsing bug" })
mcp__ruflo__hooks_model-route({ task: "fix config parsing bug" })

# Phase 2: Initialize
mcp__ruflo__swarm_init({ topology: "star", maxAgents: 1 })
mcp__ruflo__coordination_topology({ action: "set", type: "star", consensusAlgorithm: "raft" })
mcp__ruflo__agentdb_session-start()

# Phase 3: Delegate
TeamCreate({ team_name: "fix-config" })
TaskCreate({ subject: "Fix config parsing bug in parser.ts" })

# Recall before spawn (Pattern 2)
mcp__ruflo__agentdb_hierarchical-recall({ query: "config parsing" })

Agent({
  subagent_type: "coder",
  name: "config-fixer",
  team_name: "fix-config",
  prompt: "You are a **coder**. Fix the config parsing bug...\n\n## Prior agentDB Context\n{recalled data}\n\n## agentDB Protocol (MANDATORY)\n..."
})

# Verify agent stored in agentDB (Pattern 1)
mcp__ruflo__agentdb_hierarchical-recall({ query: "fix-config-config-fixer-2026-03-11" })

# Phase 4: Complete & Learn
mcp__ruflo__agentdb_session-end()
mcp__ruflo__memory_store({ key: "pattern-config-parsing-fix", value: "Star topology, single coder, fixed parser.ts bug", namespace: "patterns" })
mcp__ruflo__agentdb_pattern-store({ pattern: "config parsing fix pattern", type: "bug-fix", confidence: 0.85 })
mcp__ruflo__coordination_metrics({ metric: "all" })
mcp__ruflo__hooks_model-outcome({ taskType: "bug-fix", roles: ["coder"], success: true })
SendMessage({ to: "config-fixer", type: "shutdown_request" })
TeamDelete({ team_name: "fix-config" })
```

### Example 2: Pipeline Task (Multi-File Refactoring)

```
# Phase 1-2: routing + swarm_init(topology: "hierarchical-mesh", maxAgents: 3)

TeamCreate({ team_name: "refactor-auth" })

# Agent 1: Researcher analyzes codebase
mcp__ruflo__agentdb_hierarchical-recall({ query: "auth module research" })
Agent({ subagent_type: "researcher", name: "auth-researcher", team_name: "refactor-auth",
        prompt: "You are a **researcher**. Analyze the auth module...\n## Prior agentDB Context\n{recalled}\n## agentDB Protocol (MANDATORY)\n..." })
# -> Stores: "refactor-auth-auth-researcher-2026-03-11"

# Coordinator verifies + recalls
mcp__ruflo__agentdb_hierarchical-recall({ query: "refactor-auth-auth-researcher-2026-03-11" })

# Agent 2: Coder implements (with researcher's findings)
Agent({ subagent_type: "coder", name: "auth-coder", team_name: "refactor-auth",
        prompt: "You are a **coder**. Refactor the auth module...\n## Prior agentDB Context\n{recalled research findings}\n## agentDB Protocol (MANDATORY)\n..." })
# -> Stores: "refactor-auth-auth-coder-2026-03-11"

# Synthesize context from both agents for reviewer (Pattern 3)
mcp__ruflo__agentdb_context-synthesize({
  query: "review auth refactoring: research findings and implementation changes",
  topK: 10
})

# Agent 3: Reviewer checks changes (with synthesized context)
Agent({ subagent_type: "reviewer", name: "auth-reviewer", team_name: "refactor-auth",
        prompt: "You are a **reviewer**. Review the auth refactoring...\n## Prior agentDB Context (Synthesized)\n{synthesized context}\n## agentDB Protocol (MANDATORY)\n..." })

# Phase 4: persist patterns, shutdown all, TeamDelete
```

### Example 3: Code Review (Mesh Broadcast)

```
# Phase 1: includes diff analysis
mcp__ruflo__memory_search({ query: "code review PR" })
mcp__ruflo__hooks_route({ input: "review PR #42" })
mcp__ruflo__analyze_diff({ ref: "HEAD~3..HEAD" })
mcp__ruflo__analyze_diff-risk({ ref: "HEAD~3..HEAD" })
# Risk score > 0.7 -> escalate to include security-auditor

# Phase 2
mcp__ruflo__swarm_init({ topology: "mesh", maxAgents: 3 })
mcp__ruflo__coordination_topology({ action: "set", type: "mesh", consensusAlgorithm: "gossip" })
mcp__ruflo__agentdb_session-start()

# Phase 3: Broadcast — spawn all reviewers in parallel
TeamCreate({ team_name: "review-pr-42" })

mcp__ruflo__agentdb_hierarchical-recall({ query: "PR review patterns" })

Agent({ subagent_type: "reviewer", name: "code-reviewer", team_name: "review-pr-42",
        prompt: "You are a **reviewer**. Review PR #42 for quality...\nDiff analysis: {diff_data}\n## agentDB Protocol (MANDATORY)\n..." })

Agent({ subagent_type: "security-auditor", name: "sec-reviewer", team_name: "review-pr-42",
        prompt: "You are a **security-auditor**. Security review PR #42...\nRisk assessment: {risk_data}\n## agentDB Protocol (MANDATORY)\n..." })

# Both agents store independently, coordinator synthesizes (Pattern 4)
mcp__ruflo__agentdb_context-synthesize({
  query: "PR #42 code review and security findings",
  topK: 10
})

# Respond to user from synthesized data, then Phase 4 teardown
```
