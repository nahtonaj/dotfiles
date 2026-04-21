# agentDB Key Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate agentDB key divergence by centralizing key generation in lifecycle-hook.cjs, threading resultKey through lifecycle.json, and updating CLAUDE.md to be descriptive rather than prescriptive.

**Architecture:** Key generation functions are added to lifecycle-hook.cjs as the single source of truth. Agent-start generates resultKey and writes it to lifecycle.json. The stop hook reads resultKey from lifecycle.json (with fallback). Agents echo the key in their shutdown broadcast so the coordinator never constructs keys manually.

**Tech Stack:** Node.js (lifecycle-hook.cjs), Markdown (CLAUDE.md parts), Nix (home-manager switch for deployment)

**Spec:** `docs/superpowers/specs/2026-04-08-agentdb-key-consistency-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `~/.claude/helpers/lifecycle-hook.cjs` | Key registry functions, agent-start resultKey generation, stop hook resultKey read |
| Modify | `~/dotfiles/configs/claude/parts/base.md` | PRE_TASK, POST_TASK, Memory Flow, Data Flow Rules, Channel Roles, agentDB Parameter Reference |
| Modify | `~/dotfiles/configs/claude/parts/mode-agent-teams.md` | Phase 2 per-agent, Critical Checks |
| Modify | `~/dotfiles/configs/claude/parts/mode-bare-agent.md` | Phase 2 per-agent, Critical Checks |

---

### Task 1: Add Key Registry Functions to lifecycle-hook.cjs

**Files:**
- Modify: `~/.claude/helpers/lifecycle-hook.cjs` (near top, after imports ~line 30)

- [ ] **Step 1: Add the three key generator functions**

Add after the existing constants/imports section (after `DAEMON_TIMEOUT_MS` and similar constants):

```javascript
// ── Canonical Key Registry ──────────────────────────────────────────
// Single source of truth for all agentDB key formats.
// Every storage and recall path MUST use these functions.
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

- [ ] **Step 2: Replace inline key construction in stop hook**

At line 666, replace:
```javascript
const storeKey = leadSessionId ? `${leadSessionId}-${agentId}` : `${sessionId}-${agentId}`;
```
with:
```javascript
const storeKey = agentResultKey(leadSessionId || sessionId, agentId);
```

- [ ] **Step 3: Replace inline key construction in agent-task lookup**

At line 504, replace:
```javascript
agentDBTask = await readAgentDBKey(`agent-task-${agentId}`);
```
with:
```javascript
agentDBTask = await readAgentDBKey(agentTaskKey(agentId, ''));
```

Wait -- the current code uses `agent-task-${agentId}` where agentId already contains the full `name@teamName` from the --agent-id flag (per comment at line 150-152). The `agentTaskKey()` function would produce `agent-task-name@teamName@` with a trailing `@`. The coordinator stores keys as `agent-task-{name}@{scope}`, so agentId already IS `name@scope`.

Correct approach: leave the lookup as-is since agentId already contains the scope suffix. The function is useful for the coordinator side (constructing the key before spawn). Update to:

```javascript
agentDBTask = await readAgentDBKey(`agent-task-${agentId}`);
```

No change needed here. The `agentTaskKey()` function is for coordinator-side construction only. Add a comment:

```javascript
// agentId already contains the full 'name@scope' from --agent-id flag.
// Key matches what coordinator stores via agentTaskKey(name, scope).
agentDBTask = await readAgentDBKey(`agent-task-${agentId}`);
```

- [ ] **Step 4: Verify no other inline key constructions exist**

Search the file for any other occurrences of template literals that construct agentDB keys inline. Grep for patterns like `` `${leadSessionId}-${agentId}` `` or `` `agent-task-` `` and confirm they all use the registry functions or are the agent-task lookup (which is correct as-is).

Run: `grep -n 'agent-task-\|leadSessionId.*agentId\|sessionId.*-.*agentId' ~/.claude/helpers/lifecycle-hook.cjs`

- [ ] **Step 5: Commit**

```bash
git add ~/.claude/helpers/lifecycle-hook.cjs
git commit -m "feat(arche): add canonical key registry functions to lifecycle-hook

Single source of truth for agentDB key formats.
Stop hook now uses agentResultKey() instead of inline construction.

Co-authored-by: Isaac"
```

---

### Task 2: Generate resultKey at Agent-Start and Write to lifecycle.json

**Files:**
- Modify: `~/.claude/helpers/lifecycle-hook.cjs` (lines 490-540, the agent-start section)

- [ ] **Step 1: Generate resultKey after session state is known**

After line 495 (the initial lifecycle.json write), add resultKey generation. The key needs `leadSessionId` (which is `parentSessionId` for teammates, or `sessionId` for coordinators) and `agentId`. These are already available at this point.

After the lifecycle.json initial write (line 495), add:

```javascript
    // Generate deterministic resultKey for this agent's RESULTS storage.
    // This key is written to lifecycle.json so the agent can read it,
    // and the stop hook can use it -- single point of generation.
    const resultKey = agentResultKey(parentSessionId || sessionId, agentId || sessionId);
```

- [ ] **Step 2: Write resultKey to lifecycle.json initial state**

Modify the initial lifecycle.json write at lines 490-495. Change from:

```javascript
    fs.writeFileSync(path.join(stateDir, 'lifecycle.json'), JSON.stringify({
      sessionId,
      status: 'active',
      startedAt: new Date().toISOString(),
      taskDescription,
    }, null, 2));
```

to:

```javascript
    const resultKey = agentResultKey(parentSessionId || sessionId, agentId || sessionId);
    fs.writeFileSync(path.join(stateDir, 'lifecycle.json'), JSON.stringify({
      sessionId,
      status: 'active',
      startedAt: new Date().toISOString(),
      taskDescription,
      resultKey,
    }, null, 2));
```

(Move the `resultKey` generation to before the write so it's included in the initial state.)

- [ ] **Step 3: Write taskKey to lifecycle.json after agent-start returns**

At line 535, where `cachedResult` is written to lifecycle.json for teammates, add the resolved `taskKey`. Change from:

```javascript
        existing.cachedResult = { context: result.context, sources: result.sources || [] };
```

to:

```javascript
        existing.cachedResult = {
          context: result.context,
          sources: result.sources || [],
          taskKey: agentDBTask ? `agent-task-${agentId}` : null,
        };
```

- [ ] **Step 4: Verify lifecycle.json now contains resultKey and taskKey**

Add a temporary `console.log` after the lifecycle.json write to confirm structure during testing:

```javascript
    logToFile('DEBUG', `lifecycle.json written with resultKey=${resultKey}`);
```

(Remove after verification.)

- [ ] **Step 5: Commit**

```bash
git add ~/.claude/helpers/lifecycle-hook.cjs
git commit -m "feat(arche): generate resultKey at agent-start, write to lifecycle.json

resultKey is generated once via agentResultKey() and persisted in
lifecycle.json. Agents and stop hook both read from this single source.
taskKey also written to cachedResult for teammate context.

Co-authored-by: Isaac"
```

---

### Task 3: Stop Hook Reads resultKey from lifecycle.json

**Files:**
- Modify: `~/.claude/helpers/lifecycle-hook.cjs` (lines 660-670, the stop hook key section)

- [ ] **Step 1: Read resultKey from lifecycle.json before constructing storeKey**

Before line 665 (the current storeKey construction), add lifecycle.json read:

```javascript
    // Read resultKey from lifecycle.json (generated at agent-start).
    // Fall back to computing via agentResultKey() if missing.
    let storeKey;
    try {
      const lifecyclePath = path.join(SESSIONS_DIR, sessionId, 'lifecycle.json');
      const lifecycleData = JSON.parse(fs.readFileSync(lifecyclePath, 'utf8'));
      storeKey = lifecycleData.resultKey;
    } catch (e) {
      // lifecycle.json missing or unreadable -- fall back
    }
    if (!storeKey) {
      storeKey = agentResultKey(leadSessionId || sessionId, agentId);
    }
```

- [ ] **Step 2: Remove the old inline storeKey construction**

Remove line 666:
```javascript
const storeKey = leadSessionId ? `${leadSessionId}-${agentId}` : `${sessionId}-${agentId}`;
```

This is now handled by the code added in Step 1.

- [ ] **Step 3: Add debug log for key source**

After the storeKey resolution:

```javascript
    logToFile('DEBUG', `storeKey=${storeKey} (source=${storeKey === agentResultKey(leadSessionId || sessionId, agentId) ? 'computed' : 'lifecycle.json'})`);
```

(Can be removed after verification.)

- [ ] **Step 4: Commit**

```bash
git add ~/.claude/helpers/lifecycle-hook.cjs
git commit -m "feat(arche): stop hook reads resultKey from lifecycle.json

Falls back to agentResultKey() computation if lifecycle.json
is missing or doesn't contain resultKey. Guarantees same key
that agent-start generated.

Co-authored-by: Isaac"
```

---

### Task 4: Update CLAUDE.md base.md -- PRE_TASK and POST_TASK Templates

**Files:**
- Modify: `~/dotfiles/configs/claude/parts/base.md` (lines 57-76)

- [ ] **Step 1: Update PRE_TASK to read resultKey from lifecycle.json**

In the PRE_TASK block (line 58-63), add after step 3:

Change step 3 from the current lifecycle_context-pull instruction to:

```
3. Pull context: call `mcp__arche__lifecycle_context-pull` with `{taskDescription: "<2-3 sentence summary of your task>"}` (no sessionId needed -- agents call without it). Note the returned `context` field as ambient cross-session memory. Scan it for agentDB key references and recall via `mcp__arche__agentdb_hierarchical-recall` if useful. If the call fails or returns no context, proceed without it.
4. Read `resultKey` and `taskKey` from `~/.claude/arche/sessions/{sessionId}/lifecycle.json` -> `cachedResult`. The `resultKey` is the agentDB key where the stop hook will store your RESULTS. Include it in your shutdown broadcast.
```

Wait -- step 3 already exists. Add step 4 as a new step. The current PRE_TASK has steps 1-3. Add step 4.

- [ ] **Step 2: Update POST_TASK shutdown addendum to include resultKey**

In the POST_TASK block (line 67-75), the RESULTS block description at line 69 currently says:

```
2. End your response with a complete ## RESULTS block -- the Stop hook parses and auto-stores this block in full to agentDB working tier under key `{sessionId}-{agentId}`. This is the **primary data channel** to the coordinator, so be thorough:
```

Change to:

```
2. End your response with a complete ## RESULTS block -- the Stop hook reads `resultKey` from lifecycle.json and stores this block under that key in agentDB working tier. This is the **primary data channel** to the coordinator, so be thorough:
```

- [ ] **Step 3: Update the shutdown broadcast message format**

The POST_TASK shutdown addendum (used in agent-teams mode, appended after step 2) currently reads:

```
3. Request shutdown: SendMessage(to="*", message="[your-name] work complete. Coordinator: please send shutdown_request.", summary="Work complete, awaiting shutdown")
```

Change to:

```
3. Request shutdown: SendMessage(to="*", message="[your-name] work complete. Result key: {resultKey}. Coordinator: please send shutdown_request.", summary="Work complete, awaiting shutdown")
   Read `resultKey` from lifecycle.json (written at agent-start). This MUST be your final action.
```

- [ ] **Step 4: Commit**

```bash
git add ~/dotfiles/configs/claude/parts/base.md
git commit -m "docs(claude): update PRE_TASK/POST_TASK for resultKey flow

Agents now read resultKey from lifecycle.json and include it
in shutdown broadcasts. Stop hook description updated to reflect
lifecycle.json-based key source.

Co-authored-by: Isaac"
```

---

### Task 5: Update CLAUDE.md base.md -- Memory Flow and Data Flow Rules

**Files:**
- Modify: `~/dotfiles/configs/claude/parts/base.md` (lines 84-134)

- [ ] **Step 1: Update Memory Flow step 5**

At line 90, change:

```
5. **Findings flow** -- The Stop hook auto-stores each agent's full `## RESULTS` block to agentDB working tier under key `{sessionId}-{agentId}`; no explicit `hierarchical-store` call needed
```

to:

```
5. **Findings flow** -- The Stop hook reads `resultKey` from lifecycle.json (generated at agent-start) and stores the full `## RESULTS` block under that key in agentDB working tier. Agents echo the key in their shutdown broadcast so the coordinator can recall directly.
```

- [ ] **Step 2: Update Data Flow Rule 4**

At line 132, change:

```
4. **Recall Before Responding**: Coordinator MUST recall ALL agents' `{sessionId}-{agentId}` keys from agentDB before using their findings -- both pipeline and leaf agents. The Stop hook auto-stores the full `## RESULTS` block verbatim, so the recalled data contains complete findings. If the recalled RESULTS lists keys under `agentDB Store Keys`, recall those keys too for overflow context (large payloads, pipeline handoff data).
```

to:

```
4. **Recall Before Responding**: Coordinator MUST recall ALL agents' result keys from agentDB before using their findings. Agents echo their `resultKey` (from lifecycle.json) in shutdown broadcasts -- use that exact key for recall. If no key was received (agent crashed), fall back to `{leadSessionId}-{agentId}`. If the recalled RESULTS lists keys under `agentDB Store Keys`, recall those keys too for overflow context.
```

- [ ] **Step 3: Update Channel Roles table**

At line 97, change the agentDB hierarchical-store/recall row:

From:
```
| `agentDB hierarchical-store/recall` | Inter-agent exact-key data sharing within a session. Stop hook auto-populates working tier with full agent `## RESULTS` under `{sessionId}-{agentId}` keys | Semantic queries |
```

To:
```
| `agentDB hierarchical-store/recall` | Inter-agent exact-key data sharing within a session. Stop hook auto-populates working tier with full agent `## RESULTS` under system-generated `resultKey` (from lifecycle.json). Agents echo this key in shutdown broadcasts. | Semantic queries |
```

- [ ] **Step 4: Update agentDB Parameter Reference table**

At line 108, change the `hierarchical-store` key notes:

From:
```
| `hierarchical-store` | `key` | string | Yes | `{sessionId}-{agentId}` format (coordinator) or `{parentSessionId}-{agentId}` (teammate). For `agent-task-{name}@{scope}` keys (scope = teamName in agent-teams mode, sessionId in bare-agent mode): task description must be clean (no cross-topic keywords) -- keyword-overlap filter (>=2 matching 4+ char non-stop-words) uses it for context relevancy during synthesis |
```

To:
```
| `hierarchical-store` | `key` | string | Yes | Result keys: system-generated by `agentResultKey()` at agent-start, stored in lifecycle.json, echoed in shutdown broadcasts. Task keys: `agent-task-{name}@{scope}` (scope = teamName in agent-teams mode, sessionId in bare-agent mode) -- task description must be clean (no cross-topic keywords) for synthesis keyword-overlap filter |
```

- [ ] **Step 5: Commit**

```bash
git add ~/dotfiles/configs/claude/parts/base.md
git commit -m "docs(claude): update Memory Flow and Data Flow for resultKey

Result keys are now system-generated and echoed in shutdown
broadcasts. Coordinator recalls using received keys, not
self-constructed ones.

Co-authored-by: Isaac"
```

---

### Task 6: Update mode-agent-teams.md

**Files:**
- Modify: `~/dotfiles/configs/claude/parts/mode-agent-teams.md` (lines 43, 83)

- [ ] **Step 1: Update Phase 2 per-agent instructions**

At line 43 (the "Per-agent (non-trivial op / team)" line), the current text references explicit key format. Change:

```
**Per-agent (non-trivial op / team)**: `TaskCreate` -> `agentdb_hierarchical-store key="agent-task-{name}@{teamName}" value="{2-3 sentence task summary}" tier="working"` -> `Agent(name, team_name=teamName, run_in_background=true)` (omit `isolation` outside git repos)
```

No change needed here -- the pre-spawn task key (`agent-task-{name}@{teamName}`) is still coordinator-constructed. This is correct.

- [ ] **Step 2: Update Critical Check #5**

At line 83 (Critical Check #5), change:

From:
```
| 5 | Responding to user? Recalled ALL agents' full findings from agentDB by `{sessionId}-{agentId}` key -- both pipeline and leaf agents. Stop hook auto-persisted complete RESULTS there. Then check `agentDB Store Keys` in the recalled RESULTS -- recall any listed keys for additional context. |
```

To:
```
| 5 | Responding to user? Recalled ALL agents' result keys from agentDB -- use the `resultKey` received in each agent's shutdown broadcast. If no key received (agent crashed), fall back to `{leadSessionId}-{agentId}`. Then check `agentDB Store Keys` in the recalled RESULTS for additional context. |
```

- [ ] **Step 3: Update Shutdown Protocol message format**

At line 100-101, the shutdown addendum currently reads:

```
3. Request shutdown: SendMessage(to="*", message="[your-name] work complete. Coordinator: please send shutdown_request.", summary="Work complete, awaiting shutdown")
   This MUST be your final action. The coordinator will respond with a shutdown_request to terminate your process.
```

Change to:

```
3. Request shutdown: SendMessage(to="*", message="[your-name] work complete. Result key: {resultKey}. Coordinator: please send shutdown_request.", summary="Work complete, awaiting shutdown")
   Read `resultKey` from lifecycle.json (written at agent-start). This MUST be your final action.
```

- [ ] **Step 4: Commit**

```bash
git add ~/dotfiles/configs/claude/parts/mode-agent-teams.md
git commit -m "docs(claude): update agent-teams mode for resultKey broadcasts

Critical check #5 and shutdown addendum now reference resultKey
from lifecycle.json instead of coordinator-constructed keys.

Co-authored-by: Isaac"
```

---

### Task 7: Update mode-bare-agent.md

**Files:**
- Modify: `~/dotfiles/configs/claude/parts/mode-bare-agent.md` (lines 38, 56)

- [ ] **Step 1: Update stop hook description in Phase 2**

At line 38, change:

From:
```
**Stop hook extraction**: The Stop hook reads each agent's `## RESULTS` block and **auto-stores the full text** into agentDB working tier under key `{sessionId}-{agentId}`. This is the primary data channel -- the entire RESULTS block is stored verbatim, so agents should put ALL findings, decisions, and output there. Agents do NOT need to call `hierarchical-store` manually for their main findings -- just ensure the `## RESULTS` block is complete and thorough (all fields populated, especially `Key Findings`). For large payloads or pipeline handoffs that exceed what fits in RESULTS, agents may additionally use `hierarchical-store` and list those keys under `agentDB Store Keys` in RESULTS.
```

To:
```
**Stop hook extraction**: The Stop hook reads `resultKey` from lifecycle.json (generated at agent-start) and stores the full `## RESULTS` block under that key in agentDB working tier. This is the primary data channel -- the entire RESULTS block is stored verbatim. Agents echo `resultKey` in their completion message so the coordinator can recall directly. For large payloads or pipeline handoffs, agents may additionally use `hierarchical-store` and list those keys under `agentDB Store Keys` in RESULTS.
```

- [ ] **Step 2: Update Critical Check #4**

At line 56, change:

From:
```
| 4 | Responding to user? Recalled ALL agents' full findings from agentDB by `{sessionId}-{agentId}` key -- both pipeline and leaf agents. Stop hook auto-persisted complete RESULTS there. Then check `agentDB Store Keys` in the recalled RESULTS -- recall any listed keys for additional context. |
```

To:
```
| 4 | Responding to user? Recalled ALL agents' result keys from agentDB -- use the key from the agent's inline return or fall back to `{sessionId}-{agentId}`. Then check `agentDB Store Keys` in the recalled RESULTS for additional context. |
```

- [ ] **Step 3: Commit**

```bash
git add ~/dotfiles/configs/claude/parts/mode-bare-agent.md
git commit -m "docs(claude): update bare-agent mode for resultKey flow

Stop hook description and critical checks updated to reference
resultKey from lifecycle.json instead of inline key format.

Co-authored-by: Isaac"
```

---

### Task 8: Deploy and Verify

**Files:**
- No file changes -- deployment and verification only

- [ ] **Step 1: Rebuild CLAUDE.md via home-manager switch**

```bash
home-manager switch --flake ~/dotfiles#jon.gao@linux
```

- [ ] **Step 2: Verify deployed CLAUDE.md contains resultKey references**

```bash
grep -c 'resultKey' ~/CLAUDE.md
```

Expected: at least 5 occurrences (PRE_TASK, POST_TASK, Memory Flow, Data Flow Rule 4, Channel Roles).

- [ ] **Step 3: Verify lifecycle-hook.cjs has key registry functions**

```bash
grep -n 'function agentResultKey\|function agentTaskKey\|function planKey' ~/.claude/helpers/lifecycle-hook.cjs
```

Expected: 3 matches near the top of the file.

- [ ] **Step 4: Verify stop hook reads from lifecycle.json**

```bash
grep -n 'lifecycleData.resultKey\|resultKey.*lifecycle' ~/.claude/helpers/lifecycle-hook.cjs
```

Expected: at least 1 match in the stop hook section.

- [ ] **Step 5: Manual smoke test**

Spawn a test agent and verify:
1. lifecycle.json contains `resultKey` field after agent starts
2. Stop hook stores RESULTS under the lifecycle.json key
3. Coordinator can recall the key from the agent's shutdown broadcast

```bash
# After running a test agent, check:
cat ~/.claude/arche/sessions/*/lifecycle.json | jq '.resultKey'
```

- [ ] **Step 6: Commit all remaining changes**

```bash
git add -A
git commit -m "chore: deploy agentDB key consistency changes

home-manager switch rebuilds CLAUDE.md with resultKey flow.
lifecycle-hook.cjs updated with key registry and lifecycle.json integration.

Co-authored-by: Isaac"
```
