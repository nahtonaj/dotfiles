# agentDB Key Consistency Design

## Problem

agentDB storage keys are conventions scattered across CLAUDE.md prose docs. The stop hook writes keys using one format, the docs describe another, and the coordinator guesses a third. Specific issues:

1. **`parentSessionId` vs `leadSessionId`** -- docs say `{parentSessionId}-{agentId}` but the stop hook code (`lifecycle-hook.cjs:666`) uses `leadSessionId`.
2. **`agent-task-{name}@{scope}`** -- base.md uses generic `@{scope}`, mode files specify `@{teamName}` (agent-teams) and `@{sessionId}` (bare-agent). Coordinator must know which to use.
3. **Agent task key lookup strips `@` suffix** -- `lifecycle-hook.cjs:504` does `agentId.split('@')[0]`, undocumented behavior.

## Design

### 1. Canonical Key Registry (lifecycle-hook.cjs)

Add pure key generation functions to `lifecycle-hook.cjs`:

```javascript
function agentResultKey(leadSessionId, agentId) {
  return `${leadSessionId}-${agentId}`;
}

function agentTaskKey(agentName, scope) {
  return `agent-task-${agentName}@${scope}`;
}

function planKey(date) {
  return `plan-${date}`;
}
```

Rules:
- Stop hook calls `agentResultKey()` when storing RESULTS -- never constructs the string inline.
- `agent-start` path calls `agentTaskKey()` when looking up pre-spawn task descriptions.
- Every key format lives in these functions. Format changes happen once.

### 2. resultKey Generated at Agent-Start

`lifecycle_agent-start` generates `resultKey` using `agentResultKey()` and writes it to `lifecycle.json`:

```json
{
  "resultKey": "session-abc-agentId-xyz",
  "cachedResult": {
    "context": "...",
    "taskKey": "agent-task-coder@team-123"
  }
}
```

The agent reads `resultKey` from lifecycle.json in its MANDATORY FIRST STEP.

### 3. Agent Echoes Key in Shutdown Broadcast

The agent includes `resultKey` in its shutdown broadcast via SendMessage:

```
SendMessage(to="*", message="[coder] work complete. Result key: session-abc-agentId-xyz", summary="Work complete, awaiting shutdown")
```

The coordinator receives the exact key -- zero construction, zero guessing.

### 4. Stop Hook Reads Key from lifecycle.json

The stop hook reads `resultKey` from lifecycle.json instead of computing it. Guaranteed same key as agent-start generated.

**Fallback**: If `resultKey` is missing from lifecycle.json (e.g., agent-start failed), the stop hook computes it via `agentResultKey(leadSessionId, agentId)`. Same formula, just not pre-generated. Degraded but functional.

### 5. CLAUDE.md Updates (Descriptive, Not Prescriptive)

CLAUDE.md changes from instructing agents to construct keys to documenting what the system does:

**base.md changes:**
- PRE_TASK adds: "Read `resultKey` and `taskKey` from lifecycle.json"
- POST_TASK shutdown addendum: include `resultKey` in shutdown broadcast
- Inter-Agent Communication table: note that result keys are generated at agent-start and echoed in shutdown broadcasts
- Data Flow Rule 4: coordinator recalls keys received in shutdown broadcasts, not self-constructed
- Memory Flow step 5: stop hook reads `resultKey` from lifecycle.json
- agentDB Parameter Reference: note keys are system-generated

**mode-agent-teams.md and mode-bare-agent.md:**
- Phase 2 per-agent instructions drop explicit key format for result keys
- Critical Check #5 references shutdown broadcasts instead of key construction

**What stays convention-based:**
- `agent-task-{name}@{scope}` pre-spawn key -- coordinator constructs this before the agent exists. But `agentTaskKey()` canonicalizes the lookup, and `agent-start` echoes the resolved `taskKey` in lifecycle.json.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| lifecycle.json missing `resultKey` | Stop hook falls back to computing via `agentResultKey()` |
| agent-start fails entirely | Stop hook computes key from own context (always has sessionId + agentId) |
| Agent shutdown broadcast omits key | Coordinator falls back to constructing from CLAUDE.md formula |
| Coordinator typos pre-spawn task key | Teammate sees `taskKey: null` in lifecycle.json -- knows context didn't land |
| Bare-agent mode (no team) | Same flow. `leadSessionId` equals `sessionId`. `agentResultKey()` handles both. |

## Migration

No breaking changes. The `resultKey` field in lifecycle.json is additive. Old sessions without it trigger the fallback path (compute from formula). No backwards compatibility hacks needed.

## Key Flow Summary

```
Coordinator                          Agent                           Stop Hook
    |                                  |                                |
    |-- store agent-task-{name}@scope  |                                |
    |-- spawn Agent ------------------>|                                |
    |                                  |-- agent-start fires            |
    |                                  |   generates resultKey           |
    |                                  |   writes to lifecycle.json      |
    |                                  |-- reads lifecycle.json          |
    |                                  |   knows resultKey + taskKey     |
    |                                  |-- does work...                  |
    |                                  |-- writes ## RESULTS block       |
    |                                  |-- shutdown broadcast w/ key --->|
    |<-- receives key via SendMessage  |                                |
    |                                  |                                |-- reads resultKey from lifecycle.json
    |                                  |                                |-- stores RESULTS under that key
    |-- recalls using received key     |                                |
```
