---
name: "daily-notes"
description: "Auto-generate daily note 'In progress' section from git commits, claude-mem observations, session transcripts, and PR activity. Maps activity to task notes with effort estimation and rich markdown summaries. Invoke with /daily-notes or /daily-notes YYYY-MM-DD."
---

# Daily Notes Generator

Generate the "In progress" section of an Obsidian daily note from git commits, claude-mem observations, session transcripts, and PR activity across multiple repos.

## Invocation

- `/daily-notes` -- generate for today
- `/daily-notes 2026-04-14` -- generate for a specific date

## Timezone

This machine runs UTC but the user operates in PST (America/Los_Angeles). All date boundaries use PST:
- Use `TZ=America/Los_Angeles` when computing date boundaries for git log
- A PST day boundary translates to 07:00 or 08:00 UTC depending on DST

## Workflow

Follow these steps in order. Do not skip steps.

### Step 1: Determine Target Date

- If the user provided a date argument, use that date (format: `YYYY-MM-DD`)
- Otherwise, use today's date **in PST**: `TZ=America/Los_Angeles date +%Y-%m-%d`
- The machine runs UTC which may be a day ahead of PST -- always use the PST-aware command
- Store as `TARGET_DATE` for use in subsequent steps

### Step 2: Gather Git Activity

Run `git log` across these repos (skip any that don't exist):

```bash
# Use PST boundaries (America/Los_Angeles)
START=$(TZ=America/Los_Angeles date -d "<TARGET_DATE> 00:00:00" -u +%Y-%m-%dT%H:%M:%S)
END=$(TZ=America/Los_Angeles date -d "<TARGET_DATE> + 1 day 00:00:00" -u +%Y-%m-%dT%H:%M:%S)

# For each repo in: ~/dotfiles, ~/universe, ~/runtime
git -C <repo> log --all --since="$START" --until="$END" --format="%H|%aI|%s|%D" --name-only
```

This gives: commit hash, ISO timestamp, commit message, refs (branch names), and changed files.

Also check for runtime/universe PR activity:
- Use `mcp__devportal__devportal_read_api_call` to call `get_prs` with `type: "authored"` if available
- Filter PRs with activity on `TARGET_DATE`
- If devportal MCP is unavailable, skip this step

### Step 3: Gather Session Transcripts

Read JSONL transcripts from Claude Code sessions active on TARGET_DATE for richer context about research, decisions, and work that didn't result in commits.

**Transcript locations:**
- Coordinator transcripts: `~/.claude/projects/*/<session-id>.jsonl`
- Teammate transcripts: `~/.claude/projects/*/<session-id>/subagents/agent-*.jsonl`

**How to find relevant transcripts:**

```bash
# Find all JSONL files modified on TARGET_DATE (PST-aware)
START_EPOCH=$(TZ=America/Los_Angeles date -d "<TARGET_DATE> 00:00:00" +%s)
END_EPOCH=$(TZ=America/Los_Angeles date -d "<TARGET_DATE> + 1 day 00:00:00" +%s)
# Create markers first
touch -d @$START_EPOCH /tmp/start_marker && touch -d @$END_EPOCH /tmp/end_marker
find ~/.claude/projects/ -name "*.jsonl" -newer /tmp/start_marker ! -newer /tmp/end_marker 2>/dev/null
```

**What to extract from transcripts:**
- Scan for assistant messages (type: "assistant") containing key decisions, research findings, or task completions
- Look for tool calls that indicate significant work (file edits, git operations, MCP calls)
- Extract any `## RESULTS` blocks from agent responses
- DO NOT read entire transcripts -- they can be very large. Sample the first and last 50 lines, plus scan for `## RESULTS` blocks via grep

**Use this data to:**
- Enrich the narrative sections of daily note entries with conversation context
- Identify work that didn't result in commits (research, debugging, design discussions)
- Capture key decisions and their rationale

### Step 4: Pull claude-mem Observations

Query claude-mem's persistent memory for today's captured observations, summaries, and session context. claude-mem auto-captures observations via hooks (PostToolUse, Stop, SessionEnd) during Claude Code sessions.

**3-Layer workflow** (always follow in order for token efficiency):

1. **Search for today's observations:**
   ```
   mcp__plugin_claude-mem_mcp-search__search with:
     query="<key topics from git/transcripts, e.g., fanout, dashboard, obsidian>"
     dateStart="<TARGET_DATE>T00:00:00-07:00"
     dateEnd="<TARGET_DATE+1>T00:00:00-07:00"
     orderBy="date_desc"
     limit=30
   ```
   Returns index of observation IDs with short titles (~50-100 tokens each).

2. **Get timeline context** around interesting observations:
   ```
   mcp__plugin_claude-mem_mcp-search__timeline with:
     anchor=<ID from step 1>
     depth_before=2
     depth_after=2
   ```

3. **Fetch full details** only for filtered IDs:
   ```
   mcp__plugin_claude-mem_mcp-search__get_observations with:
     ids=[<specific IDs>]
   ```

**Alternative: smart_search** for semantic queries:
```
mcp__plugin_claude-mem_mcp-search__smart_search with:
  query="<natural language question about today's work>"
```

**Use this data to:**
- Get structured summaries of session work (decisions, patterns, completions)
- Capture work that didn't result in commits (research, debugging, design)
- Cross-reference with git commits to build complete picture
- Find recurring themes or patterns across sessions

NEVER fetch full details without filtering first -- the 3-layer workflow provides 10x token savings.

### Step 5: Fallback to Raw Transcripts

If claude-mem returns sparse or empty results for TARGET_DATE (e.g., the corpus hasn't captured the sessions yet), rely on the raw JSONL transcripts gathered in Step 3 for session context. Step 3 already covers how to locate and sample them.

### Step 6: Map Activity to Tasks

Apply branch-to-task mapping rules:

| Pattern | Task Note |
|---------|-----------|
| `stack/fanout-*` branches, runtime repo fanout paths | `[[Kafka fanout]]` |
| universe `db-agents` paths | `[[agent-orchestrator]]` |
| dotfiles `.claude/agents/*` or `.claude/skills/*` paths | `[[agent-orchestrator]]` |
| dotfiles `nix/*` or `flake.*` paths | `[[nix config]]` |
| dotfiles tmux-related paths | `[[tmux config]]` |
| Unmatched | derive task name from branch name or primary file path |

For each mapped task name, verify it exists in the vault:
```
mcp__obsidian__obsidian_list_notes with path "tasks/" and search for the task name
```

Group all commits by their mapped task.

### Step 7: Estimate Effort

For each task group, calculate effort from commit timestamps:
- Get the earliest and latest commit timestamp in the group
- Time span = latest - earliest
- Apply heuristic:
  - **< 1 hour** (or single commit): `0.25 day`
  - **1-4 hours**: `0.5 day`
  - **> 4 hours**: `1 day`

### Step 8: Generate Content

For each task group, generate a section in this format:

```markdown
## [[Task Name]]
- [effort:: <estimated effort>] [notes:: <1-sentence summary derived from commit messages>]

<Rich markdown narrative of work done>

Commits:
- `<short-hash>` <commit message>
- `<short-hash>` <commit message>

<PR links if any>
<Key decisions or context from claude-mem observations if any>
```

Order task sections by effort (highest first).

**Data source priority for narrative generation:**
1. **claude-mem observations** -- most structured, auto-captured session summaries with decisions and patterns
2. **Git commits** -- concrete changes, use for commit lists and file references
3. **Session transcripts** -- richest raw context for decisions and rationale (fallback if claude-mem is incomplete)

When multiple sources cover the same work, prefer claude-mem observations for the summary line (`[notes::]`) and combine all sources for the rich markdown body. Use `claude-mem:mem-search` skill for natural-language queries when you need to find specific past work.

### Step 9: Check Existing Daily Note

Read the current daily note:
```
mcp__obsidian__obsidian_read_note with path "daily/<TARGET_DATE>.md"
```

Three cases:
1. **Note exists with existing "In progress" content:** Identify which tasks are already documented. Only generate sections for NEW tasks not already present. Present as an append operation.
2. **Note exists but "In progress" section is empty:** Generate all task sections.
3. **Note does not exist:** Report that no daily note exists for this date. Suggest the user create one from the daily template first (via Templater in Obsidian), then re-run `/daily-notes`.

### Step 10: Present for Review

Show the complete generated content to the user. Format it clearly:

```
Here is the generated content for daily/<TARGET_DATE>.md:

---
[generated markdown sections]
---

Tasks documented: <count>
Total effort: <sum> days
New task notes needed: <list of tasks that don't exist in tasks/ folder>

Approve, edit, or reject?
```

Wait for explicit user approval before proceeding. Use `AskUserQuestion` if needed.

### Step 11: Write to Vault

After user approval:

1. Write the approved content to the daily note:
   ```
   mcp__obsidian__obsidian_update_note with path "daily/<TARGET_DATE>.md", content=<approved content>, mode="append"
   ```
   Target the append after the `# In progress` heading and any existing content.

2. For each task that needs a new task note (user approved in Step 8):
   ```
   mcp__obsidian__obsidian_update_note with path "tasks/<Task Name>.md", content=<task template>, mode="overwrite"
   ```
   Use the task note template:
   ```markdown
   ---
   creation date: <current datetime>
   modification date: <current datetime>
   ---
   start:: [[<TARGET_DATE>]]
   `button-done`

   ~~~dataview
   table without id
     file.link as "Date",
     L.effort as effort,
     L.notes as notes
   from "daily"
   flatten file.lists as L
   where contains(L.outlinks, this.file.link) OR (contains(meta(L.section).subpath, this.file.name) AND L.effort)
   flatten L.effort as effort
   flatten L.notes as notes
   sort file.link DESC
   ~~~
   ~~~dataview
   TABLE WITHOUT ID
     sum(rows.effort) as "Effort",
     length(rows) + " sessions" as "Notes"
   FROM "daily"
   FLATTEN file.lists as L
   WHERE contains(L.outlinks, this.file.link) OR (contains(meta(L.section).subpath, this.file.name) AND L.effort)
   FLATTEN L.effort as effort
   GROUP BY null
   ~~~
   ```

### Step 12: Summary

Report what was written:
- Tasks documented (with effort for each)
- Total effort for the day
- New task notes created
- Any tasks skipped (already documented)

## Edge Cases

- **No activity found:** Report "No git activity found for <TARGET_DATE>" -- do not write an empty section
- **Existing entries for same task:** Skip that task and note it was already documented
- **Multiple repos same task:** Merge commits from all repos under one task heading
- **Weekend/off days:** Still scan -- user may have committed on weekends
- **devportal MCP unavailable:** Skip PR activity gathering, proceed with git-only data

## Important Rules

- NEVER overwrite the nav links or Dataview callouts at the top of daily notes
- ALWAYS preserve existing content when appending
- ALWAYS use the heading-based format (`## [[Task Name]]` + `- [effort::] [notes::]`)
- ALWAYS get user approval before writing to the vault
- ALWAYS verify task note existence before deciding to create new ones
