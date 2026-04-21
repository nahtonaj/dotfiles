# Obsidian Notes Agent & Daily Notes Skill -- Design Spec

**Date:** 2026-04-14
**Status:** Draft
**Author:** spec-writer agent

---

## Overview

Two deliverables:
1. **Agent definition** (`obsidian-notes`) -- domain-aware Obsidian vault agent for daily notes, brag sheet updates, and vault cleanup/optimization
2. **Skill** (`daily-notes`) -- auto-generates the "In progress" section of daily notes from git/PR/arche activity

---

## 1. Agent: `obsidian-notes`

**File:** `.claude/agents/custom/obsidian-notes.md`
**Model:** `claude-opus-4-6`
**Category:** `custom`

### Vault Structure

```
*PINNED*/          -- Brag sheet.md, Tasks.md (pinned reference notes)
attachments/       -- Pasted images
copilot/           -- Copilot custom prompts
daily/             -- YYYY-MM-DD.md daily notes (Templater + Dataview)
notes/             -- Long-form technical notes (Databricks, Kafka, fanout, etc.)
proposals/         -- Design proposals
snippets/          -- Code snippets, credentials (GCP service creds)
tasks/             -- Task tracking notes with Dataview effort aggregation
templates/         -- Templater templates (daily, tasks, notes, proposals)
```

### Note Format Conventions

**Daily notes** (`daily/YYYY-MM-DD.md`):
- Header: nav links (`<< yesterday || month || tomorrow >>`)
- Dataview callouts: Todo (open tasks) and Completed (tasks finished today)
- `# In progress` section with button -- this is where work entries go
- Work entries use **heading-based format** (see Daily Note Format below)

**Task notes** (`tasks/<name>.md`):
- Frontmatter: `creation date`, `modification date`
- `start::` inline field linking to start date
- `button-done` for completion
- Two Dataview queries: detail table (Date, effort, notes) and aggregate table (total Effort, session count)
- Dataview queries use backwards-compatible WHERE clause:
  ```
  WHERE contains(L.outlinks, this.file.link) OR (contains(meta(L.section).subpath, this.file.name) AND L.effort)
  ```

**Brag sheet** (`*PINNED*/Brag sheet.md`):
- Structured as Impact (Direct/Indirect value), Skills, Citizenship
- Entries link to daily note dates and JIRA tickets
- Format: `[[date]]` header, then `# [Title](jira-link)`, then Impact/Skills/Citizenship subsections

### Daily Note Format (heading-based, backwards-compatible)

Each task worked on gets a section:

```markdown
## [[Task Name]]
- [effort:: 0.5 day] [notes:: one-sentence summary for Dataview table]

Rich markdown content here -- full formatting, code blocks, bullet lists.
Commits, PR links, key decisions, detailed narrative.

- Bullet points with details
- `code references` and **formatting** work here
```

**Rules:**
- `## [[Task Name]]` heading provides the Dataview section link + visual structure
- `- [effort::] [notes::]` list item provides Dataview-queryable inline fields
- Rich markdown body below for full detail (not captured by Dataview, visible in daily note)
- `effort` uses duration format: `0.25 day`, `0.5 day`, `1 day`, `2h`, `4h`
- `notes` is a 1-sentence summary/teaser for the Dataview table on the task page

**Backwards compatibility:** Old format (`- [[Task]] [effort:: 1 day] [notes:: ...]`) still works alongside new format. The Dataview query on task pages handles both via the OR clause.

### Effort Heuristic

When auto-generating daily notes, estimate effort from git activity:
- **< 1 hour** of commit activity on a task: `0.25 day`
- **1-4 hours**: `0.5 day`
- **> 4 hours**: `1 day`
- Time span calculated from first to last commit timestamp per task group
- If only 1 commit with no time span, use `0.25 day`

### Branch-to-Task Mapping

Default mappings (configurable):

| Pattern | Task Note |
|---------|-----------|
| `stack/fanout-*` branches, runtime repo fanout paths | `[[Kafka fanout]]` |
| arche repo commits | `[[agent-orchestrator]]` |
| dotfiles claude/agents/skills paths | `[[agent-orchestrator]]` |
| dotfiles tmux paths | auto-create `[[tmux config]]` if missing |
| dotfiles nix paths | auto-create `[[nix config]]` if missing |
| ruflo repo commits | `[[agent-orchestrator]]` |
| Unmatched | auto-create task note from branch name or primary file path |

### Task Note Auto-Creation

When activity doesn't match any existing task, create a new task note using this template:

```markdown
---
creation date: <current datetime>
modification date: <current datetime>
---
start:: [[<today's date>]]
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

### Agent Capabilities

1. **Daily note generation** (via daily-notes skill)
2. **Brag sheet updates** -- extract impactful work from daily notes into brag sheet format (Impact/Skills/Citizenship sections)
3. **Vault cleanup/optimization:**
   - Identify orphaned notes (no inlinks or outlinks)
   - Standardize formatting across notes
   - Deduplicate similar content
   - Fix broken links
   - Ensure all task notes have the backwards-compatible Dataview query
4. **Note improvement** -- enhance existing notes with better structure, links, and formatting

### Review-Before-Write Requirement

**CRITICAL:** The agent MUST always present proposed changes to the user for review before writing to the vault. This applies to ALL write operations:
- Daily note generation: show the full generated content, ask user to confirm/edit before writing
- Brag sheet updates: show proposed entries, get approval
- Cleanup/optimization: list all proposed changes with before/after, get approval
- Task note creation: show proposed task name and template, get approval
- Note improvement: show diff of proposed changes, get approval

The agent should use `AskUserQuestion` or present the content inline and wait for user confirmation. Never auto-write to the vault without explicit approval.

### Available MCP Tools

The agent has access to `mcp__obsidian__*` tools:
- `obsidian_read_note` -- read note content and metadata
- `obsidian_update_note` -- append, prepend, or overwrite notes
- `obsidian_list_notes` -- list files/folders with filtering and recursion
- `obsidian_global_search` -- search across vault
- `obsidian_manage_frontmatter` -- read/update frontmatter fields
- `obsidian_manage_tags` -- add/remove/rename tags
- `obsidian_search_replace` -- find and replace across notes
- `obsidian_delete_note` -- delete notes (requires user confirmation)

### Guidelines

- NEVER overwrite the nav links or Dataview callouts at the top of daily notes
- ALWAYS preserve existing content when appending to daily notes
- ALWAYS use the heading-based format for new daily note entries
- ALWAYS include both `effort::` and `notes::` inline fields in the list item
- ALWAYS use the backwards-compatible Dataview query in new task notes
- Respect the `templates/` directory -- reference templates but don't modify them
- The `.config/nvim` directory is a git submodule -- don't touch it

---

## 2. Skill: `daily-notes`

**File:** `.claude/skills/daily-notes/daily-notes.md`
**Invocation:** `/daily-notes` or `/daily-notes 2026-04-14` (specific date)

### YAML Frontmatter

```yaml
---
name: daily-notes
description: Auto-generate daily note "In progress" section from git commits, arche sessions, and PR activity. Maps activity to task notes with effort estimation and rich markdown summaries.
---
```

### Skill Flow

1. **Determine target date** -- today by default, or user-specified date
2. **Gather git activity** across repos:
   - `git log --since=<date> --until=<date+1>` for: `~/dotfiles`, `~/arche`, `~/ruflo`
   - Include commit hash, timestamp, message, files changed
   - Check for runtime/universe PR activity via devportal MCP if available
3. **Gather arche session data:**
   - List `~/.claude/arche/sessions/` directories from target date
   - Read lifecycle.json context summaries for session descriptions
4. **Map activity to tasks:**
   - Apply branch-to-task mapping rules (see table above)
   - Match against existing task notes in `tasks/` folder via `obsidian_list_notes`
   - Group commits by mapped task
5. **Estimate effort** per task group using the heuristic (commit time span)
6. **Generate content** for each task group:
   - `## [[Task Name]]` heading
   - `- [effort:: <estimated>] [notes:: <1-sentence summary from commit messages>]`
   - Rich markdown body: narrative of what was done, commit references, PR links, key decisions
7. **Check existing daily note:**
   - Read current daily note via `obsidian_read_note`
   - If "In progress" section already has content, present as update (append new tasks, skip already-documented ones)
   - If daily note doesn't exist, generate full note from daily template
8. **Present for review:**
   - Show the complete generated content to the user
   - User can edit, approve, or reject
   - Only write to vault after explicit approval
9. **Write to vault:**
   - Use `obsidian_update_note` to write approved content
   - Create any missing task notes (also with user approval)
10. **Summary:** Report what was written -- tasks documented, effort totals, any new task notes created

### Edge Cases

- **No activity found:** Report "no git activity found for <date>" -- don't write an empty section
- **Existing entries for same task:** Append to existing task section or skip with note to user
- **Multiple repos same task:** Merge activity from all repos under one task heading
- **Weekend/off days:** Still scan -- user may have committed on weekends

---

## 3. Future Extensions (out of scope for v1)

- Weekly/monthly summary skill aggregating from daily notes
- Auto-update brag sheet skill that extracts high-impact entries
- Vault health dashboard skill showing orphaned notes, broken links, formatting issues
- PR-to-note skill that creates a technical note from a PR diff
