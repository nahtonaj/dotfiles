# Obsidian Notes Agent & Daily Notes Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create an `obsidian-notes` agent definition and a `daily-notes` skill that auto-generates daily note content from git/PR/arche activity.

**Architecture:** Two markdown files -- an agent definition at `.claude/agents/custom/obsidian-notes.md` (processed by `claude.nix` activation script with model injection) and a skill at `.claude/skills/daily-notes/SKILL.md` (symlinked directly by `claude.nix`). No code, no tests -- these are Claude instruction files. The agent provides domain knowledge for vault operations; the skill provides a step-by-step workflow for `/daily-notes` invocation.

**Tech Stack:** Markdown with YAML frontmatter, Obsidian MCP tools (`mcp__obsidian__*`), git CLI, Nix home-manager deployment (existing `claude.nix` handles both).

---

## File Structure

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `.claude/agents/custom/obsidian-notes.md` | Agent definition -- vault structure knowledge, note format conventions, daily note format, effort heuristic, branch-to-task mapping, task note auto-creation template, brag sheet format, cleanup capabilities, review-before-write requirement, MCP tool reference, guidelines |
| Create | `.claude/skills/daily-notes/SKILL.md` | Skill definition -- YAML frontmatter, 10-step daily-notes workflow, edge case handling, output format |

**Deployment notes:**
- The agent file is automatically processed by `nix/modules/claude.nix` `processAgentsScript` at `home-manager switch` time. The script injects the `model:` field and the Ruflo workflow block. So the agent file should include frontmatter with `model`, `name`, `description`, `category` but the model value will be overwritten at deploy time.
- The skill directory is symlinked directly: `ln -sfn "${dotfilesDir}/.claude/skills" "$HOME/.claude/skills"` (line 135 of `claude.nix`). Skill files MUST be named `SKILL.md` inside a directory matching the skill name.
- No changes to `claude.nix` or `nix/home/default.nix` are needed -- both are already set up to deploy agents and skills recursively.

---

### Task 1: Create the `obsidian-notes` agent definition

**Files:**
- Create: `.claude/agents/custom/obsidian-notes.md`

This is the largest deliverable. The agent file contains all vault domain knowledge, note format conventions, and operational guidelines. Use the existing `.claude/agents/custom/nix-specialist.md` as a structural reference (YAML frontmatter format, section organization, RESULTS block at the end).

- [ ] **Step 1: Create the agent file with YAML frontmatter**

Create `.claude/agents/custom/obsidian-notes.md` with this exact content:

````markdown
---
model: "claude-opus-4-6"
name: obsidian-notes
description: Domain-aware Obsidian vault agent for daily notes, brag sheet updates, and vault cleanup/optimization
category: custom
---

# Obsidian Notes Agent

You are a domain-aware Obsidian vault agent. You help with daily note generation (via the `/daily-notes` skill), brag sheet updates, vault cleanup/optimization, and note improvement. You have deep knowledge of this vault's structure, note formats, and Dataview conventions.

## Vault Structure

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

## Note Format Conventions

### Daily Notes (`daily/YYYY-MM-DD.md`)

Structure (top to bottom):
1. Nav links: `<< yesterday || month || tomorrow >>` (NEVER overwrite these)
2. Dataview callouts: Todo (open tasks) and Completed (tasks finished today) (NEVER overwrite these)
3. `# In progress` section with button -- this is where work entries go
4. Work entries use the heading-based format below

### Task Notes (`tasks/<name>.md`)

- Frontmatter: `creation date`, `modification date`
- `start::` inline field linking to start date
- `button-done` for completion
- Two Dataview queries: detail table (Date, effort, notes) and aggregate table (total Effort, session count)
- Dataview queries use backwards-compatible WHERE clause:
  ```
  WHERE contains(L.outlinks, this.file.link) OR (contains(meta(L.section).subpath, this.file.name) AND L.effort)
  ```

### Brag Sheet (`*PINNED*/Brag sheet.md`)

- Structured as Impact (Direct/Indirect value), Skills, Citizenship
- Entries link to daily note dates and JIRA tickets
- Format: `[[date]]` header, then `# [Title](jira-link)`, then Impact/Skills/Citizenship subsections

## Daily Note Entry Format (heading-based)

Each task worked on gets a section under `# In progress`:

```markdown
## [[Task Name]]
- [effort:: 0.5 day] [notes:: one-sentence summary for Dataview table]

Rich markdown content here -- full formatting, code blocks, bullet lists.
Commits, PR links, key decisions, detailed narrative.

- Bullet points with details
- `code references` and **formatting** work here
```

Rules:
- `## [[Task Name]]` heading provides the Dataview section link + visual structure
- `- [effort::] [notes::]` list item on the FIRST line after the heading provides Dataview-queryable inline fields
- Rich markdown body below for full detail (not captured by Dataview, visible in daily note)
- `effort` uses duration format: `0.25 day`, `0.5 day`, `1 day`, `2h`, `4h`
- `notes` is a 1-sentence summary/teaser for the Dataview table on the task page

Backwards compatibility: Old format (`- [[Task]] [effort:: 1 day] [notes:: ...]`) still works alongside this format. The Dataview query on task pages handles both via the OR clause.

## Effort Heuristic

When estimating effort from git activity:
- **< 1 hour** of commit activity on a task: `0.25 day`
- **1-4 hours**: `0.5 day`
- **> 4 hours**: `1 day`
- Time span calculated from first to last commit timestamp per task group
- If only 1 commit with no time span, use `0.25 day`

## Branch-to-Task Mapping

| Pattern | Task Note |
|---------|-----------|
| `stack/fanout-*` branches, runtime repo fanout paths | `[[Kafka fanout]]` |
| arche repo commits | `[[agent-orchestrator]]` |
| dotfiles claude/agents/skills paths | `[[agent-orchestrator]]` |
| dotfiles tmux paths | auto-create `[[tmux config]]` if missing |
| dotfiles nix paths | auto-create `[[nix config]]` if missing |
| ruflo repo commits | `[[agent-orchestrator]]` |
| Unmatched | auto-create task note from branch name or primary file path |

## Task Note Auto-Creation Template

When activity doesn't match any existing task, create a new task note:

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

## Capabilities

1. **Daily note generation** -- invoke the `/daily-notes` skill or manually compose daily note entries
2. **Brag sheet updates** -- extract impactful work from daily notes into brag sheet format (Impact/Skills/Citizenship sections)
3. **Vault cleanup/optimization:**
   - Identify orphaned notes (no inlinks or outlinks)
   - Standardize formatting across notes
   - Deduplicate similar content
   - Fix broken links
   - Ensure all task notes have the backwards-compatible Dataview query
4. **Note improvement** -- enhance existing notes with better structure, links, and formatting

## Review-Before-Write Requirement

**CRITICAL:** You MUST always present proposed changes to the user for review before writing to the vault. This applies to ALL write operations:
- Daily note generation: show the full generated content, ask user to confirm/edit before writing
- Brag sheet updates: show proposed entries, get approval
- Cleanup/optimization: list all proposed changes with before/after, get approval
- Task note creation: show proposed task name and template, get approval
- Note improvement: show diff of proposed changes, get approval

Use `AskUserQuestion` or present the content inline and wait for user confirmation. Never auto-write to the vault without explicit approval.

## Available MCP Tools

You have access to `mcp__obsidian__*` tools:
- `obsidian_read_note` -- read note content and metadata
- `obsidian_update_note` -- append, prepend, or overwrite notes
- `obsidian_list_notes` -- list files/folders with filtering and recursion
- `obsidian_global_search` -- search across vault
- `obsidian_manage_frontmatter` -- read/update frontmatter fields
- `obsidian_manage_tags` -- add/remove/rename tags
- `obsidian_search_replace` -- find and replace across notes
- `obsidian_delete_note` -- delete notes (requires user confirmation)

## Guidelines

- NEVER overwrite the nav links or Dataview callouts at the top of daily notes
- ALWAYS preserve existing content when appending to daily notes
- ALWAYS use the heading-based format for new daily note entries
- ALWAYS include both `effort::` and `notes::` inline fields in the list item
- ALWAYS use the backwards-compatible Dataview query in new task notes
- Respect the `templates/` directory -- reference templates but don't modify them
- The `.config/nvim` directory is a git submodule -- don't touch it
- Always read a note before editing it

## Structured Report (ALWAYS include at end of response)

```
## RESULTS
- **Status**: completed | partial | blocked
- **Files Changed**: [list of files modified with paths]
- **Key Findings**: [bullet list of important discoveries]
- **Patterns Discovered**: [reusable patterns for agentDB storage]
- **Cross-Team Context**: [information other teammates should know]
```
````

- [ ] **Step 2: Verify the file was created correctly**

Run:
```bash
head -5 .claude/agents/custom/obsidian-notes.md
```

Expected output:
```
---
model: "claude-opus-4-6"
name: obsidian-notes
description: Domain-aware Obsidian vault agent for daily notes, brag sheet updates, and vault cleanup/optimization
category: custom
```

- [ ] **Step 3: Commit the agent definition**

```bash
git add .claude/agents/custom/obsidian-notes.md
git commit -m "feat(claude): add obsidian-notes agent definition

Domain-aware Obsidian vault agent with knowledge of vault structure,
daily note heading-based format, effort heuristic, branch-to-task
mapping, task note auto-creation, and review-before-write requirement."
```

---

### Task 2: Create the `daily-notes` skill

**Files:**
- Create: `.claude/skills/daily-notes/SKILL.md`

The skill defines the `/daily-notes` slash command workflow. Use existing skills like `.claude/skills/quicktree/SKILL.md` as a structural reference (directory with `SKILL.md` inside, YAML frontmatter with `name` and `description`).

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p .claude/skills/daily-notes
```

- [ ] **Step 2: Create the skill file**

Create `.claude/skills/daily-notes/SKILL.md` with this exact content:

````markdown
---
name: "daily-notes"
description: "Auto-generate daily note 'In progress' section from git commits, arche sessions, and PR activity. Maps activity to task notes with effort estimation and rich markdown summaries. Invoke with /daily-notes or /daily-notes YYYY-MM-DD."
---

# Daily Notes Generator

Generate the "In progress" section of an Obsidian daily note from git commits, arche sessions, and PR activity across multiple repos.

## Invocation

- `/daily-notes` -- generate for today
- `/daily-notes 2026-04-14` -- generate for a specific date

## Workflow

Follow these steps in order. Do not skip steps.

### Step 1: Determine Target Date

- If the user provided a date argument, use that date (format: `YYYY-MM-DD`)
- Otherwise, use today's date
- Store as `TARGET_DATE` for use in subsequent steps

### Step 2: Gather Git Activity

Run `git log` across these repos (skip any that don't exist):

```bash
# For each repo in: ~/dotfiles, ~/arche, ~/ruflo
git -C <repo> log --all --since="<TARGET_DATE>T00:00:00" --until="<TARGET_DATE+1>T00:00:00" --format="%H|%aI|%s|%D" --name-only
```

This gives: commit hash, ISO timestamp, commit message, refs (branch names), and changed files.

Also check for runtime/universe PR activity:
- Use `mcp__devportal__devportal_read_api_call` to call `get_prs` with `type: "authored"` if available
- Filter PRs with activity on `TARGET_DATE`
- If devportal MCP is unavailable, skip this step

### Step 3: Gather Arche Session Data

```bash
# List session directories from target date
ls -d ~/.claude/arche/sessions/*<TARGET_DATE>* 2>/dev/null
```

For each matching session directory:
- Read `lifecycle.json` and extract the `context` field from `cachedResult`
- This provides session descriptions and task summaries

### Step 4: Map Activity to Tasks

Apply branch-to-task mapping rules:

| Pattern | Task Note |
|---------|-----------|
| `stack/fanout-*` branches, runtime repo fanout paths | `[[Kafka fanout]]` |
| arche repo commits | `[[agent-orchestrator]]` |
| dotfiles `.claude/agents/*` or `.claude/skills/*` paths | `[[agent-orchestrator]]` |
| dotfiles `nix/*` or `flake.*` paths | `[[nix config]]` |
| dotfiles tmux-related paths | `[[tmux config]]` |
| ruflo repo commits | `[[agent-orchestrator]]` |
| Unmatched | derive task name from branch name or primary file path |

For each mapped task name, verify it exists in the vault:
```
mcp__obsidian__obsidian_list_notes with path "tasks/" and search for the task name
```

Group all commits by their mapped task.

### Step 5: Estimate Effort

For each task group, calculate effort from commit timestamps:
- Get the earliest and latest commit timestamp in the group
- Time span = latest - earliest
- Apply heuristic:
  - **< 1 hour** (or single commit): `0.25 day`
  - **1-4 hours**: `0.5 day`
  - **> 4 hours**: `1 day`

### Step 6: Generate Content

For each task group, generate a section in this format:

```markdown
## [[Task Name]]
- [effort:: <estimated effort>] [notes:: <1-sentence summary derived from commit messages>]

<Rich markdown narrative of work done>

Commits:
- `<short-hash>` <commit message>
- `<short-hash>` <commit message>

<PR links if any>
<Key decisions or context from arche sessions if any>
```

Order task sections by effort (highest first).

### Step 7: Check Existing Daily Note

Read the current daily note:
```
mcp__obsidian__obsidian_read_note with path "daily/<TARGET_DATE>.md"
```

Three cases:
1. **Note exists with existing "In progress" content:** Identify which tasks are already documented. Only generate sections for NEW tasks not already present. Present as an append operation.
2. **Note exists but "In progress" section is empty:** Generate all task sections.
3. **Note does not exist:** Report that no daily note exists for this date. Suggest the user create one from the daily template first (via Templater in Obsidian), then re-run `/daily-notes`.

### Step 8: Present for Review

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

### Step 9: Write to Vault

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

### Step 10: Summary

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
````

- [ ] **Step 3: Verify the skill file was created correctly**

Run:
```bash
head -5 .claude/skills/daily-notes/SKILL.md
```

Expected output:
```
---
name: "daily-notes"
description: "Auto-generate daily note 'In progress' section from git commits, arche sessions, and PR activity. Maps activity to task notes with effort estimation and rich markdown summaries. Invoke with /daily-notes or /daily-notes YYYY-MM-DD."
---
```

- [ ] **Step 4: Commit the skill**

```bash
git add .claude/skills/daily-notes/SKILL.md
git commit -m "feat(claude): add daily-notes skill for auto-generating daily note entries

Skill invoked via /daily-notes gathers git activity across repos,
maps commits to Obsidian task notes, estimates effort, generates
heading-based daily note sections, and writes to vault after user
approval."
```

---

### Task 3: Validate deployment

**Files:**
- None modified -- validation only

- [ ] **Step 1: Verify agent will be picked up by claude.nix**

The `processAgentsScript` in `nix/modules/claude.nix` processes all `.md` files under `.claude/agents/` recursively. Confirm the new file is in the right place:

```bash
ls -la .claude/agents/custom/obsidian-notes.md
```

Expected: file exists with non-zero size.

- [ ] **Step 2: Verify skill will be picked up by claude.nix**

The skill directory is symlinked directly (`ln -sfn "${dotfilesDir}/.claude/skills" "$HOME/.claude/skills"`). Confirm the new directory and file exist:

```bash
ls -la .claude/skills/daily-notes/SKILL.md
```

Expected: file exists with non-zero size.

- [ ] **Step 3: Dry-run the home-manager build**

```bash
home-manager build --flake .#jon.gao@linux
```

Expected: build succeeds without errors. This validates that the new files don't break the Nix build.

- [ ] **Step 4: Commit validation result (if any fixes were needed)**

If the build failed and required fixes, commit them:
```bash
git add -A
git commit -m "fix(claude): resolve build issues with obsidian-notes agent/skill"
```

If no fixes needed, skip this step.
