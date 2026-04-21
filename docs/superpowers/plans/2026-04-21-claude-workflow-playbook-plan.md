# Claude Workflow Playbook (Phase A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Phase A deliverables from `docs/superpowers/specs/2026-04-21-claude-workflow-playbook-design.md`: a first-person playbook at `docs/claude-workflow/` consisting of one `README.md` (10 narrative sections, ~2750 words) and six appendix files (200-600 words each) that a Databricks engineer can follow end-to-end in under 30 minutes.

**Architecture:** Docs-only. No code, no tests. Each task produces one artifact (a file or a single section), validates it against an explicit checklist drawn from the spec, then commits. The plan treats the spec as the source of truth: every section/appendix has an anchor back to spec line ranges so the writer cannot drift. Cross-links get validated in a dedicated final task so they are checked as a whole rather than piecemeal.

**Tech Stack:** Markdown (GitHub-flavored). ASCII only. No emoji, no smart quotes. Commands in fenced code blocks with language tags. Git for commits.

---

## File Structure

All files live under `docs/claude-workflow/` (new directory, created in Task 1). Each appendix carries a `Last verified against:` footer (Claude Code + claude-mem + db-agents version strings captured at the top of the session). README has none of that -- it is the entry point, not a reference.

| File | Role | Target words |
|---|---|---|
| `docs/claude-workflow/README.md` | 10-section narrative playbook, entry point | ~2750 |
| `docs/claude-workflow/appendix-claude-md.md` | HARD RULES walkthrough | ~450 |
| `docs/claude-workflow/appendix-helpers.md` | Three-bucket helper categorization | ~500 |
| `docs/claude-workflow/appendix-databricks-tools.md` | db-agents install + MCP recommendations | ~400 |
| `docs/claude-workflow/appendix-skills.md` | Workflow-critical Superpowers skills | ~300 |
| `docs/claude-workflow/appendix-agent-teams.md` | Agent teams deep dive + HARD RULE 3 caveats | ~600 |
| `docs/claude-workflow/appendix-verification.md` | Verify-before-claim examples | ~300 |

**Version stamps to capture once at the start of Task 2** (used verbatim in every appendix's `Last verified against:` footer):

```bash
claude --version                                    # Claude Code
jq -r '.plugins.repositories["claude-plugins-official"].plugins["claude-mem"].version' \
  /home/jon.gao/dotfiles/configs/claude/settings.json     # claude-mem
gh release list --repo databricks-eng/universe-dev --limit 20 | grep db-agents | head -1 | cut -f3
```

Concatenate into the format: `Last verified against: Claude Code X.Y.Z, claude-mem A.B.C, db-agents vP.Q.R (2026-04-21).`

---

## Writing Rules (apply to every task that writes content)

These come from spec section 4.3 (lines 62-68) and 4.4 (lines 70-74). **Re-read before every content task.**

- First-person ("I", "we"). Direct, opinionated. Short sentences.
- ASCII only, no emoji, no smart quotes. Validate with `LC_ALL=C grep -n '[^[:print:][:space:]]' <file>` -- must return nothing.
- Commands in fenced code blocks with language tags (e.g., ` ```bash `).
- File references use `path/from/repo/root:line` form when the line number matters.
- Every named Claude Code feature cites the skill or plugin (e.g., `` `superpowers:brainstorming` ``).
- README section N links to its appendix in the first paragraph.
- Every appendix has a "Back to README" link at the top pointing to the specific README section it expands on (use anchor links like `../claude-workflow/README.md#5-phase-3-execute-with-coordinator--teams`).
- Appendices cross-link each other rather than duplicating (HARD RULES canonical in `appendix-claude-md.md`; HARD RULE 3 specifics canonical in `appendix-agent-teams.md`).

Word counts are targets, not ceilings. Staying within +/- 20% is fine; exceeding +50% is a signal to compress.

---

## Task 1: Create `docs/claude-workflow/` directory and commit the empty skeleton

**Files:**
- Create: `docs/claude-workflow/README.md` (placeholder only)

- [ ] **Step 1: Create the directory and a placeholder README**

```bash
mkdir -p /home/jon.gao/dotfiles/docs/claude-workflow
```

Create `docs/claude-workflow/README.md` with exactly this content (no more, no less -- the real sections land in later tasks):

```markdown
# Claude Workflow Playbook

Work in progress. Sections land incrementally; see `docs/superpowers/plans/2026-04-21-claude-workflow-playbook-plan.md` for the build order.
```

- [ ] **Step 2: Verify the file is ASCII-only and stages cleanly**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
```

Expected: no output (exit 0).

```bash
cd /home/jon.gao/dotfiles && git status --short docs/claude-workflow/
```

Expected: `?? docs/claude-workflow/README.md`.

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): scaffold playbook directory

Create docs/claude-workflow/ with a placeholder README. Content lands
incrementally per plan 2026-04-21-claude-workflow-playbook-plan.md.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds, `git log -1 --stat` shows `1 file changed, 3 insertions(+)`.

---

## Task 2: Capture version stamps and record them in the plan

**Files:**
- Modify: create a local scratch file `docs/claude-workflow/.verified-against.txt` (untracked; used by later tasks).

- [ ] **Step 1: Run the version capture commands and record**

```bash
echo "Claude Code: $(claude --version 2>&1 | head -1)"
echo "claude-mem:  $(jq -r '.plugins.repositories["claude-plugins-official"].plugins["claude-mem"].version' /home/jon.gao/dotfiles/configs/claude/settings.json 2>&1)"
echo "db-agents:   $(gh release list --repo databricks-eng/universe-dev --limit 20 2>&1 | grep db-agents | head -1 | cut -f3)"
```

Example expected output:

```
Claude Code: claude-code/2.5.0 linux-x64
claude-mem:  12.1.6
db-agents:   db-agents-v1.5.7
```

- [ ] **Step 2: Write the versions into a scratch file used by later tasks**

```bash
cat > /home/jon.gao/dotfiles/docs/claude-workflow/.verified-against.txt <<EOF
Last verified against: Claude Code <X.Y.Z>, claude-mem <A.B.C>, db-agents <vP.Q.R> (2026-04-21).
EOF
```

Replace the angle-bracketed placeholders with the actual version strings from Step 1. This file is untracked (add to the plan's mental gitignore -- do not `git add` it).

- [ ] **Step 3: Add the scratch file to `.gitignore`**

Open `/home/jon.gao/dotfiles/.gitignore` and append one line:

```
docs/claude-workflow/.verified-against.txt
```

- [ ] **Step 4: Commit the gitignore update**

```bash
cd /home/jon.gao/dotfiles
git add .gitignore
git commit -m "$(cat <<'EOF'
chore(gitignore): ignore claude-workflow version-stamp scratch file

The .verified-against.txt file is used during playbook authoring to
paste the Last-verified-against footer into each appendix. Not meant
for tracking.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 3: Write README section 1 ("Why this doc")

Anchor: spec `docs/superpowers/specs/2026-04-21-claude-workflow-playbook-design.md` section 4.1 line 42.

**Files:**
- Modify: `docs/claude-workflow/README.md` (replace the placeholder with a real title + table-of-contents + section 1)

- [ ] **Step 1: Replace the placeholder with the README skeleton + section 1 content**

Overwrite `docs/claude-workflow/README.md` with:

```markdown
# Claude Workflow Playbook

A first-person walkthrough of how I run Claude Code day-to-day at Databricks. The loop is brainstorm, plan, execute, verify, and the mechanics are coordinator-plus-agent-teams. Ten sections, roughly 2750 words, skimmable in under 30 minutes.

Target reader: a Databricks engineer who already has Claude Code installed and wants a more structured workflow than ad-hoc prompting.

## Table of contents

1. [Why this doc](#1-why-this-doc)
2. [The loop in one picture](#2-the-loop-in-one-picture)
3. [Phase 1 -- Brainstorm](#3-phase-1----brainstorm)
4. [Phase 2 -- Plan](#4-phase-2----plan)
5. [Phase 3 -- Execute with coordinator + teams](#5-phase-3----execute-with-coordinator--teams)
6. [Phase 4 -- Verify](#6-phase-4----verify)
7. [Commit, remember, move on](#7-commit-remember-move-on)
8. [Common failure modes](#8-common-failure-modes)
9. [Minimum viable adoption](#9-minimum-viable-adoption)
10. [Living with a moving target](#10-living-with-a-moving-target)

Appendices (in `docs/claude-workflow/`):

- `appendix-claude-md.md` -- HARD RULES walkthrough.
- `appendix-helpers.md` -- Three-bucket helper categorization.
- `appendix-databricks-tools.md` -- db-agents install + MCP recommendations.
- `appendix-skills.md` -- Workflow-critical Superpowers skills.
- `appendix-agent-teams.md` -- Agent teams deep dive.
- `appendix-verification.md` -- Verify-before-claim examples.

---

## 1. Why this doc

Before I adopted this loop, every substantial Claude Code task I ran hit one of three failure modes. The first was **one-shot drift**: I would open a chat, describe a problem, and accept whatever came back. The first answer was usually plausible and usually wrong in ways I only noticed after the code was already merged. The second was **unverified claims**: the model would assert "tests pass" or "this is the root cause" and I would forward those assertions into PR descriptions without running the verification myself. The third was **ad-hoc agent spawning**: as soon as tasks got large enough to want parallelism, I was spawning subagents with no shared protocol, losing their output, and spending more time reconciling than doing.

The loop fixes all three. Brainstorming explicitly converts a fuzzy ask into a written spec. Writing plans explicitly converts the spec into bite-sized checkbox tasks. Executing with coordinator-plus-agent-teams means the coordinator stays lightweight and every spawn uses a named team with a shutdown protocol. Verifying before claiming is a HARD RULE, not a polite suggestion -- every factual assertion needs file:line citations or command output. And when the whole thing is over, I commit, let claude-mem remember the session, and move on.

Section 2 shows the loop as a single picture. Sections 3-7 walk each phase. Section 8 is the catalog of mistakes I still make when I get lazy. Section 9 is the minimum-viable path for someone who wants to try one piece at a time. Section 10 is the mindset for keeping this doc useful as Claude Code evolves -- practices persist, protocols do not.
```

- [ ] **Step 2: Verify ASCII-only and section-1 anchor**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
```

Expected: no output.

```bash
grep -c '^## 1\. Why this doc' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
```

Expected: `1`.

- [ ] **Step 3: Word count is roughly 150w for section 1**

```bash
awk '/^## 1\. Why this doc/,/^## 2\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: between 130 and 250 (target 150, +/- 20% is fine, +50% triggers compression).

- [ ] **Step 4: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 1 (why this doc)

First narrative section: the three failure modes (one-shot drift,
unverified claims, ad-hoc agent spawning) that the loop fixes.
Establishes the doc's voice (first-person, direct, opinionated) and
previews sections 2-10.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 4: Write README section 2 ("The loop in one picture")

Anchor: spec section 4.1 line 43.

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 2 content after section 1**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 2. The loop in one picture

```
  +-------------+        +------------+        +---------+        +--------+
  |  Brainstorm | -----> |    Plan    | -----> | Execute | -----> | Verify |
  +-------------+        +------------+        +---------+        +--------+
     spec.md                plan.md             coordinator         evidence
     (sec 3)                (sec 4)             + agent teams       (sec 6)
                                                  (sec 5)
                                                       |
                                                       v
                                               +------------------+
                                               | Commit, remember |
                                               |   (sec 7)        |
                                               +------------------+
```

Four phases plus a cleanup step. Each arrow is a handoff where the output of the previous phase becomes a read-only input to the next.

- **Brainstorm** uses `superpowers:brainstorming` to convert a fuzzy ask into a written spec under `docs/superpowers/specs/`.
- **Plan** uses `superpowers:writing-plans` to break the spec into bite-sized checkbox tasks under `docs/superpowers/plans/`.
- **Execute** uses a **coordinator** (me, in the Claude Code session) that delegates to **agent teams** (spawned via `TeamCreate` / `Agent` / `SendMessage`). The coordinator stays lightweight per HARD RULE 1 in `configs/claude/CLAUDE.md`; agents do the heavy work per `superpowers:subagent-driven-development`.
- **Verify** uses `superpowers:verification-before-completion`. Every claim needs file:line citations or command output.
- **Commit and remember** uses `commit-commands:commit-push-pr` and lets the `claude-mem` plugin capture the session into cross-session memory.

The rest of this doc is one section per phase plus the meta-sections.
```

- [ ] **Step 2: Verify ASCII-only and word count**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
```

Expected: no output.

```bash
awk '/^## 2\. The loop in one picture/,/^## 3\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: between 130 and 250.

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 2 (loop diagram)

ASCII diagram of brainstorm -> plan -> execute -> verify -> commit,
naming the Superpowers skills and the coordinator role that section 5
will expand.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 5: Write README section 3 ("Phase 1 -- Brainstorm")

Anchor: spec section 4.1 line 44.

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 3 content**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 3. Phase 1 -- Brainstorm

Open a Claude Code session and invoke `superpowers:brainstorming` before you write anything. The skill is explicit that you MUST run it before creative work; I treat that as literal. The skill reads your initial ask and interrogates the design space before any code or plan is produced.

**What a good input looks like.** One paragraph naming the user-visible outcome plus two or three constraints that are already load-bearing. Examples of load-bearing constraints: "must ship as a Claude Code marketplace plugin", "must work without the universe repo checkout", "under a hundred lines of SKILL.md". Examples of things that are not load-bearing: specific file paths I intend to touch, naming conventions, testing framework choices. Those belong in the plan, not the brainstorm.

**Signals that you have enough to stop.** The brainstorming output is a written spec with a Summary, Goals / Non-goals, concrete deliverables, open questions, and an "out of scope" section. When I can read that spec and imagine a plan-writing teammate going from there to checkbox tasks without asking me clarifying questions, brainstorming is done. If open questions materially block the plan, resolve them first -- they are not Plan-A work.

**Where the spec lives.** `docs/superpowers/specs/YYYY-MM-DD-<feature>-design.md`, one file per brainstorm output. Commit it before moving to planning, even if it is still draft-status. The reason: the plan-writer reads the spec verbatim; if the spec is not committed, the plan references a moving target.

See `appendix-claude-md.md` for the HARD RULES that govern how the coordinator delegates during the brainstorm (short version: I do not write the spec myself -- a subagent does, and I review).
```

- [ ] **Step 2: Verify ASCII-only and word count**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
awk '/^## 3\. Phase 1 -- Brainstorm/,/^## 4\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: no non-ASCII, word count between 200 and 380 (target 250).

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 3 (phase 1 - brainstorm)

Invoking superpowers:brainstorming, what good inputs look like, stop
signals, where specs live, pointer to appendix-claude-md for the
delegation protocol.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 6: Write README section 4 ("Phase 2 -- Plan")

Anchor: spec section 4.1 line 45.

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 4 content**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 4. Phase 2 -- Plan

Planning uses `superpowers:writing-plans`. The input is the spec you just committed; the output is `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` -- one file per plan, one plan per implementable subsystem.

**Spec-to-plan boundary.** The spec answers "what are we building and why"; the plan answers "exactly which files does each task touch, what is the minimal code for that task, and how do I verify it worked." If the plan starts restating requirements, you are smearing the boundary. If the plan starts containing code blocks longer than the thing they replace, you are writing implementation, not a plan -- stop and invoke `superpowers:test-driven-development` instead.

**When to split into multiple plans.** If the spec covers two or more independent subsystems, write one plan per subsystem. The test is: could a plan execute to a working, testable end state without waiting on the other plan? If yes, split. If the plans share state mid-execution, they should be one plan.

**Locations.**
- Specs: `docs/superpowers/specs/YYYY-MM-DD-<feature>-design.md`
- Plans: `docs/superpowers/plans/YYYY-MM-DD-<feature>-plan.md` (or `-<subsystem>-plan.md` when splitting)

Commit the plan before executing. Same reason as the spec: the executor reads the plan verbatim, and a moving target in a plan is worse than a moving target in a spec because the tasks are intentionally terse.

`superpowers:writing-plans` includes a self-review checklist (spec coverage, placeholder scan, type consistency). I run it before handing off, not after.
```

- [ ] **Step 2: Verify ASCII-only and word count**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
awk '/^## 4\. Phase 2 -- Plan/,/^## 5\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: no non-ASCII, word count between 240 and 450 (target 300).

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 4 (phase 2 - plan)

superpowers:writing-plans, spec-to-plan boundary, when to split,
file locations, commit-before-execute discipline.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 7: Write README section 5 ("Phase 3 -- Execute with coordinator + teams")

Anchor: spec section 4.1 line 46. This is the longest section (~450w) and must explicitly mention: HARD RULES from `configs/claude/CLAUDE.md`, coordinator stays lightweight, every Agent call uses a team, spawn/coordinate/shutdown lifecycle, Pipeline Context, worktrees, the SendMessage-is-not-source-of-truth sentence, db-agents dashboard as monitoring surface.

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 5 content**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 5. Phase 3 -- Execute with coordinator + teams

Execution is where the loop earns its keep. I run in Claude Code as the **coordinator**; every non-trivial read, edit, or bash call goes to a subagent via `TeamCreate` + `Agent`. The rules that make this work are in `configs/claude/CLAUDE.md` -- see `appendix-claude-md.md` for the annotated walkthrough. The short version follows.

**Coordinator stays lightweight.** HARD RULE 1. I may run one `Read`/`Grep`/`Glob` for a factual question or one read-only bash call for a status check; anything more goes to an agent. The reason is context economy: every token I spend reading a file is a token I cannot spend coordinating. When I violate this rule, it is always because "just this once" -- and the next thing I know I am fifteen tool calls deep into a diff and have forgotten what the teammate just asked.

**Every Agent call uses a team.** HARD RULE 2. `team_name` is required on every spawn. Sole exception: a single `Explore`/`Glob`/`Grep` agent for a quick read-only lookup. Teams exist because `SendMessage` is team-scoped and without them you cannot route messages or verify delivery.

**Spawn, coordinate, shutdown.** HARD RULE 3. Spawn: `TeamDelete` defensively, then `TeamCreate`, then `Agent(name, team_name, run_in_background=true)`. Coordinate: all inter-agent communication uses `SendMessage`; task assignments and status flow via `TaskUpdate`. Shutdown: the lead sends `{type: "shutdown_request"}` to each teammate, waits for `shutdown_response` with `approve: true`, then calls `TeamDelete`. Details in `appendix-agent-teams.md`.

**SendMessage is the primary channel but not the source of truth.** Upstream bugs (Claude Code issues #43706, #38932, #42999) can silently drop messages in either direction. HARD RULE 3 permits reading persisted inbox files at `~/.claude/teams/{team-name}/inboxes/*.json` as a disk-based verification channel. When in doubt, read the inbox file on disk. Details in `appendix-agent-teams.md`.

**Pipeline Context is the coordinator's only reliable prior-output channel.** When agent N+1 needs output from agent N, I inline that output under a `Pipeline Context` heading in the N+1 prompt. References do not survive the context handoff; content does.

**Worktrees for concurrent edits.** When two or more agents will edit the same repo concurrently, pass `isolation: "worktree"` to `Agent`. This is the difference between a clean merge and three hours of reconciliation.

**db-agents is the monitoring surface for long-running fleets.** When I am running a team of five-plus agents for more than a few minutes, the `db-agents` web dashboard (see `appendix-databricks-tools.md`) shows each agent's state (IDLE / BUSY / INPUT) and lets me intervene without opening ten Claude Code panes. Installation is bundled with the `claude-workflow-bootstrap` plugin.
```

- [ ] **Step 2: Verify ASCII-only, word count, and all required mentions**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
awk '/^## 5\. Phase 3 -- Execute/,/^## 6\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: no non-ASCII, word count between 370 and 680 (target 450).

```bash
section5=$(awk '/^## 5\. Phase 3 -- Execute/,/^## 6\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md)
echo "$section5" | grep -c 'HARD RULE'
echo "$section5" | grep -c 'TeamCreate\|SendMessage\|TaskUpdate'
echo "$section5" | grep -c 'Pipeline Context'
echo "$section5" | grep -c 'worktree'
echo "$section5" | grep -c 'inbox'
echo "$section5" | grep -c 'db-agents'
```

Expected: each count >= 1.

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 5 (phase 3 - execute)

HARD RULES 1-3 from configs/claude/CLAUDE.md, coordinator-lightweight,
team-scoped spawns, spawn/coordinate/shutdown lifecycle, SendMessage
reliability caveat with the inbox escape hatch, Pipeline Context,
worktree isolation, db-agents as monitoring surface. Points into
appendix-claude-md, appendix-agent-teams, appendix-databricks-tools.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 8: Write README section 6 ("Phase 4 -- Verify")

Anchor: spec section 4.1 line 47.

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 6 content**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 6. Phase 4 -- Verify

Verification is HARD RULE 4 in `configs/claude/CLAUDE.md` and it is the rule I break most often when tired. I invoke `superpowers:verification-before-completion` before any claim that work is complete, fixed, or passing.

**Evidence is file:line citations plus command output.** Not reasoning. Not pattern-matching on how things "usually go". Not "the error message suggests". Reading the code that produces the behavior, pasting the output of the test, naming the exact line where the assertion lives.

**Zero tolerance for unverified claims.** A single assertion made without evidence is a rule violation. This sounds extreme and is extreme, and the reason it has to be extreme is that one unverified claim buried in a PR comment trains the reader to trust the other ninety. If I cannot cite evidence, I retract -- "I suspect but have not confirmed" is better than "this fails because Z" with no receipt.

**Where I use this explicitly.** Before saying "tests pass" in any status message, I run the tests and paste the last line. Before writing "root cause" in a PR description, I cite the file:line that produces the behavior. Before approving a shutdown_request from a teammate, I verify their RESULTS block against the actual diff they produced. Subagent-reported citations with file:line snippets count as evidence and I do not redundantly re-verify.

Concrete examples of good vs. bad evidence in `appendix-verification.md`.
```

- [ ] **Step 2: Verify ASCII-only and word count**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
awk '/^## 6\. Phase 4 -- Verify/,/^## 7\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: no non-ASCII, word count between 200 and 380 (target 250).

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 6 (phase 4 - verify)

HARD RULE 4 from configs/claude/CLAUDE.md. Evidence standard (file:line
citations + command output), zero-tolerance policy, concrete usage
points, pointer to appendix-verification for examples.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 9: Write README section 7 ("Commit, remember, move on")

Anchor: spec section 4.1 line 48.

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 7 content**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 7. Commit, remember, move on

The tail of the loop is three actions I do every time, not just when I feel like it.

**Commit via `commit-commands:commit-push-pr`.** The skill handles the body format, co-author trailer, and (optionally) pushing and opening a PR. I use the `commit-commands:commit` variant when I want to commit without pushing. The point of using the skill instead of running `git commit` directly is consistency -- commit messages are the part of the repo history I read most and the one most likely to rot when I hand-roll them.

**Remember via `claude-mem`.** The `claude-mem` plugin has a Stop hook that captures the session into cross-session memory. I do nothing; the plugin runs on session end. Later sessions query that memory via `claude-mem:mem-search` ("did we already solve this?") and `claude-mem:knowledge-agent` ("what do I know about X?"). The critical property is that memory is cross-session, not cross-repository -- the plugin scopes observations to the current working directory by default.

**PR review via `pr-review-toolkit:review-pr`.** When I open a PR, I run the review skill as a sanity check before asking a human. It is a cheap second pair of eyes.

Then I close the Claude Code session and move on. The next time I open a session in this repo, claude-mem primes context automatically -- I do not re-explain what I was working on.
```

- [ ] **Step 2: Verify ASCII-only and word count**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
awk '/^## 7\. Commit, remember, move on/,/^## 8\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: no non-ASCII, word count between 160 and 300 (target 200).

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 7 (commit, remember, move on)

commit-commands:commit-push-pr for consistency, claude-mem Stop hook
for cross-session memory, pr-review-toolkit:review-pr as pre-human
sanity check.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 10: Write README section 8 ("Common failure modes")

Anchor: spec section 4.1 line 49.

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 8 content**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 8. Common failure modes

These are the mistakes I still make, organized by symptom. When a session is going wrong, I check this list before anything else.

**Coordinator doing heavy work.** I open a file "just to check one thing" and half an hour later I am eight tool calls deep into a diff. Symptom: I cannot remember what the teammate is waiting for. Fix: stop, send the teammate a status update from whatever partial state I have, and delegate the open thread.

**Agent spawn without `team_name`.** The spawn succeeds but `SendMessage` fails silently because there is no team to route through. Symptom: my teammate is "running" but never responds. Fix: `TeamDelete`, respawn with `team_name` set.

**Skipping brainstorm.** I jump straight to writing a plan because the problem "seems obvious." Symptom: halfway through execution I realize two of the constraints contradict. Fix: pause, invoke `superpowers:brainstorming`, produce a spec, resume.

**Claiming "tests pass" without running them.** HARD RULE 4 violation. Symptom: the PR lands and CI fails. Fix: always run the verification command and paste the last line of output.

**Over-sharing between agents.** I include ten thousand lines of prior context in every agent prompt "just to be safe." Symptom: agents run out of context mid-task and their edits become erratic. Fix: trust the Pipeline Context heading -- if agent N+1 does not need agent N's output verbatim, summarize.

**Polling teammates in-band.** I send `SendMessage` status-check DMs because I am impatient. Symptom: teammate inboxes fill with meta-messages that drown the real findings. Fix: read the persisted inbox file on disk (`~/.claude/teams/{team-name}/inboxes/*.json`) -- HARD RULE 3 explicitly permits this as verification, not polling.
```

- [ ] **Step 2: Verify ASCII-only and word count**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
awk '/^## 8\. Common failure modes/,/^## 9\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: no non-ASCII, word count between 200 and 380 (target 250).

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 8 (common failure modes)

Six recurring mistakes organized by symptom and fix: coordinator doing
heavy work, spawn without team_name, skipping brainstorm, unverified
test claims, over-sharing context, polling teammates in-band.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 11: Write README section 9 ("Minimum viable adoption")

Anchor: spec section 4.1 line 50. This is the longest section after section 5 (~500w) and must be a graduated path with a 1-line success check per step.

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 9 content**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 9. Minimum viable adoption

The full loop is a lot to adopt at once. Here is the graduated path I recommend for a Databricks teammate going from zero to steady state. Each step has a one-line success check -- if the check passes, move on; if it does not, fix before proceeding.

**Step 1 -- Install the bootstrap plugin.**

```bash
/plugin install claude-workflow-bootstrap
```

Success check: `claude-workflow-bootstrap` appears in `/plugin list`.

The plugin lives at `plugin-marketplace/eng-ingestion-team/claude-workflow-bootstrap/`. It configures your `~/.claude/CLAUDE.md` with HARD RULES, sets `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, installs the team-cleanup hook, and installs the db-agents binary + its integration hooks. See `appendix-databricks-tools.md` for what db-agents does and `appendix-claude-md.md` for the HARD RULES walkthrough.

**Step 2 -- Try the loop on one small task.**

Pick something throwaway: a README typo, a one-line refactor. Brainstorm it (overkill on purpose), write a two-task plan, execute with one agent, verify. Commit.

Success check: you can recite, without looking, which skill runs in each phase.

**Step 3 -- Add Superpowers.**

```bash
/plugin install superpowers
```

Success check: `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:subagent-driven-development`, `superpowers:verification-before-completion` all appear in the skill list.

Re-run Step 2's exercise using `superpowers:subagent-driven-development` instead of inline execution. Notice how much less context the coordinator holds.

**Step 4 -- Adopt claude-mem.**

```bash
/plugin install claude-mem
```

Success check: open a new session tomorrow and run `claude-mem:mem-search "<something from today>"` -- it finds your session.

**Step 5 -- Run db-agents on the side.**

The bootstrap plugin already installed the binary. Start it on Arca:

```bash
nvm use 24 && db-agents
```

Port-forward 13100 from your Mac (SSH config: `LocalForward 13100 localhost:13100`). Open http://localhost:13100. See `appendix-databricks-tools.md` for full setup details.

Success check: the dashboard shows at least one IDLE agent card for your current session.

**Step 6 -- Read the failure-modes list (section 8) one more time.**

You will repeat at least three of those mistakes in your first week. Having already seen them listed makes the debugging shorter.

Success check: you catch yourself about to violate a HARD RULE, pause, and course-correct without being told.
```

- [ ] **Step 2: Verify ASCII-only and word count**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
awk '/^## 9\. Minimum viable adoption/,/^## 10\./' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: no non-ASCII, word count between 400 and 750 (target 500).

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 9 (minimum viable adoption)

Six-step graduated path (bootstrap plugin, small-task loop, Superpowers,
claude-mem, db-agents, failure-modes reread). One-line success check
per step. Names the marketplace directory
plugin-marketplace/eng-ingestion-team/claude-workflow-bootstrap/.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 12: Write README section 10 ("Living with a moving target")

Anchor: spec section 4.1 line 51. Must include: practices-persist-protocols-don't, agent-teams example with commit `1fb845a` citation, memory example with native-memory-evaluation question, doc-maintenance ground rules (owner, cadence, versioning).

**Files:**
- Modify: `docs/claude-workflow/README.md`

- [ ] **Step 1: Append section 10 content**

Append to `docs/claude-workflow/README.md`:

```markdown

---

## 10. Living with a moving target

Claude Code ships features fast, which means every specific tool name in this doc will eventually be wrong. The principle that keeps the doc useful across those changes: **practices persist, protocols do not**.

A practice is "the coordinator delegates heavy work and verifies from a source of truth." A protocol is "call `TeamCreate` then `Agent` then `SendMessage`." The practice is load-bearing; the protocol is implementation. When Anthropic renames `TeamCreate` next quarter, the practice keeps working, and the most I have to change in this doc is a set of find-and-replace edits.

**Agent teams -- live example.** `TeamCreate` / `SendMessage` / `TaskUpdate` is today's surface. Known bugs: Claude Code issues #43706, #38932, #42999 can silently drop `SendMessage` in either direction. Commit `1fb845a` on `main` is the protocol-evolves-but-practice-persists pattern: the protocol did not change, but the delivery layer turned out to be lossy, so HARD RULE 3 in `configs/claude/CLAUDE.md` now permits reading persisted inbox files at `~/.claude/teams/{team-name}/inboxes/*.json` as a disk-based verification channel. The durable practice (coordinator delegates, agents communicate via explicit channels, coordinator verifies from source of truth, never polls in-band) survived the fix intact.

**Memory -- live example.** `claude-mem` is the right choice today. Claude Code is shipping native memory features that will likely subsume some or all of it. Do not pin the tool; teach yourself the evaluative question:

> "What do I need to remember across sessions? Does the native feature cover it? Does claude-mem still add value on top?"

When native memory matures, you re-answer the question and adjust; you do not re-read the whole playbook.

**Doc-maintenance ground rules.**

- Owner: I maintain this until I name a successor. If you want to take it over, open a PR updating this line.
- Cadence: revisit on any Claude Code minor release that touches agents or memory. "Revisit" means re-read, not necessarily rewrite.
- Versioning: every appendix carries a "Last verified against: Claude Code X.Y.Z, claude-mem A.B.C, db-agents vP.Q.R (YYYY-MM-DD)" footer. When the versions on disk diverge from the footer by more than one minor bump, re-verify the appendix and update the footer.
```

- [ ] **Step 2: Verify ASCII-only, word count, and required mentions**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
awk '/^## 10\. Living with a moving target/,0' /home/jon.gao/dotfiles/docs/claude-workflow/README.md | wc -w
```

Expected: no non-ASCII, word count between 200 and 380 (target 250).

```bash
section10=$(awk '/^## 10\. Living with a moving target/,0' /home/jon.gao/dotfiles/docs/claude-workflow/README.md)
echo "$section10" | grep -c 'practices persist'
echo "$section10" | grep -c '1fb845a'
echo "$section10" | grep -c '#43706\|#38932\|#42999'
echo "$section10" | grep -c 'claude-mem'
echo "$section10" | grep -c 'native memory'
echo "$section10" | grep -c 'Last verified against'
```

Expected: each count >= 1.

- [ ] **Step 3: Total README word count check**

```bash
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/README.md
```

Expected: between 2200 and 3500 (target 2750, +/- 20% acceptable).

- [ ] **Step 4: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/README.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): README section 10 (living with a moving target)

Practices-persist-protocols-do-not principle, agent-teams live example
citing commit 1fb845a and issues #43706/#38932/#42999, memory
evaluation question for native-memory transition, doc-maintenance
ground rules (owner/cadence/versioning footer).

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds. README is complete.

---

## Task 13: Write `appendix-claude-md.md`

Anchor: spec section 4.2 line 56. ~450w. Annotated walkthrough of the HARD RULES block from `configs/claude/CLAUDE.md`; what each rule defends against; how to customize for your team.

**Files:**
- Create: `docs/claude-workflow/appendix-claude-md.md`

- [ ] **Step 1: Read the current HARD RULES block to anchor the walkthrough**

```bash
awk '/^## HARD RULES/,/^## Precedence/' /home/jon.gao/dotfiles/configs/claude/CLAUDE.md | head -80
```

This is the canonical source. Every rule citation in the appendix must match the text here.

- [ ] **Step 2: Create the appendix file**

Create `docs/claude-workflow/appendix-claude-md.md` with:

```markdown
[Back to README](README.md#5-phase-3-execute-with-coordinator--teams)

# Appendix: The HARD RULES block

The four HARD RULES in `configs/claude/CLAUDE.md` are the load-bearing part of the entire workflow. Every other piece of this playbook is scaffolding around them. This appendix walks each rule, says what it defends against, and notes how to customize for a team with different constraints.

## HARD RULE 1 -- Delegate implementation work to agents

Verbatim intent: for any file editing, writing, multi-step research, or implementation, spawn an agent. Direct tool use is for trivial one-call read-only ops only.

**What it defends against:** coordinator context bloat. Every token spent reading a file is a token not available for coordination. Without this rule I drift into "just one more read" and lose the thread of what my teammates are waiting for.

**Carve-outs I actually use:**
- One `Read` for a factual question ("what port does X listen on?").
- One `Grep`/`Glob` for a location ("where is Y defined?").
- One read-only bash (`git status`, `ls`, port check).

**Customization:** if your team reviews agent diffs more aggressively than solo work, you can loosen this rule. If you work with unreliable agents, you can tighten it -- forbid carve-outs entirely.

## HARD RULE 2 -- Every Agent call uses a team

Verbatim intent: `team_name` required on every spawn. Sole exception: a single `Explore`/`Glob`/`Grep` agent for a quick read-only lookup.

**What it defends against:** untracked spawns. Teams exist because `SendMessage` is team-scoped; without a team you cannot route messages or verify delivery. Spawning without a team silently defeats the entire coordination protocol.

**Customization:** the exception list can widen if your workflow spawns lots of cheap read-only agents. Keep the whitelist narrow; the cost of adding a team is trivial compared to debugging a lost spawn.

## HARD RULE 3 -- Team lifecycle

Covered in depth in `appendix-agent-teams.md`. The short version: spawn (`TeamDelete` defensive -> `TeamCreate` -> `Agent`), coordinate (`SendMessage` + `TaskUpdate`, persisted inbox files as source of truth), shutdown (`shutdown_request` -> `shutdown_response` -> `TeamDelete`). The appendix also covers the three additions commit `1fb845a` made to this rule.

## HARD RULE 4 -- Verify before you claim

Verbatim intent: every factual assertion needs direct evidence (code read, command run, output observed). Never assert based on intuition or pattern-matching.

**What it defends against:** trained-in plausibility. Language models are very good at sounding correct. The rule forces a physical check before the assertion leaves my mouth (or keyboard).

**Zero tolerance.** A single unverified claim asserted as fact is a violation. This is extreme on purpose: one unverified claim buried in a PR comment trains the reader to doubt the other ninety.

**Customization:** I have not loosened this one and do not recommend it. If you work in a low-stakes area you can soften the zero-tolerance to "flag, re-verify, then commit" -- but the evidence requirement stays.

## Precedence

When rules conflict: explicit user instructions in this turn > `CLAUDE.md` rules > skill instructions > default system behavior. Concrete example: if the user tells me "just commit" and my CLAUDE.md says "never run git writes on main", I surface the conflict and ask -- I do not silently do either thing.

Last verified against: Claude Code <X.Y.Z>, claude-mem <A.B.C>, db-agents <vP.Q.R> (2026-04-21).
```

Replace the `<X.Y.Z>` / `<A.B.C>` / `<vP.Q.R>` placeholders with the captured values from Task 2's `.verified-against.txt`.

- [ ] **Step 3: Verify ASCII-only, word count, cross-links, and footer**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-claude-md.md
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/appendix-claude-md.md
grep -c '^\[Back to README\]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-claude-md.md
grep -c 'Last verified against' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-claude-md.md
grep -c '^## HARD RULE [1-4]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-claude-md.md
```

Expected: no non-ASCII, word count between 370 and 680 (target 450), Back-to-README link count = 1, footer count = 1, HARD RULE section count = 4.

- [ ] **Step 4: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/appendix-claude-md.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): add appendix-claude-md.md

Annotated walkthrough of HARD RULES 1-4 from configs/claude/CLAUDE.md
plus the Precedence rule. For each: verbatim intent, what it defends
against, customization notes. Points to appendix-agent-teams for the
HARD RULE 3 deep dive.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 14: Write `appendix-helpers.md`

Anchor: spec section 4.2 line 57 + section 5.5 for the three-bucket taxonomy. ~500w. Each Bucket 1 entry cites `configs/claude/settings.json` line range where it is wired.

**Files:**
- Create: `docs/claude-workflow/appendix-helpers.md`

- [ ] **Step 1: Read settings.json to confirm current line ranges**

```bash
grep -n 'team-cleanup\|status-reporter\|auto-approve' /home/jon.gao/dotfiles/configs/claude/settings.json
awk 'NR>=270 && NR<=500 && /(PreToolUse|PostToolUse|UserPromptSubmit|SessionStart|SessionEnd|Stop|PreCompact|Subagent|PermissionRequest|Notification)/' /home/jon.gao/dotfiles/configs/claude/settings.json | head -30
```

Note the line numbers returned. The appendix cites these ranges verbatim; if they differ from the 273-500 range the spec assumed, use the actual numbers.

- [ ] **Step 2: Read the spec's Bucket 3 list to copy the helper names exactly**

```bash
awk '/\*\*Bucket 3/,/^The plugin/' /home/jon.gao/dotfiles/docs/superpowers/specs/2026-04-21-claude-workflow-playbook-design.md
```

- [ ] **Step 3: Create the appendix file**

Create `docs/claude-workflow/appendix-helpers.md` with:

```markdown
[Back to README](README.md#5-phase-3-execute-with-coordinator--teams)

# Appendix: Helper categorization

My full install has ~40 helper scripts under `.claude/helpers/` plus integration hooks shipped by `db-agents`. For an honest answer to "what does the documented workflow actually require", every helper lands in one of three buckets.

## Bucket 1 -- Required for the documented workflow (installed by v0.1)

Wired into `configs/claude/settings.json` and load-bearing. All three install automatically when you run the `claude-workflow-bootstrap` plugin.

| Helper | Event(s) wired | settings.json range | How it arrives on disk |
|---|---|---|---|
| `team-cleanup.sh` | `SessionEnd` | see `configs/claude/settings.json` around the SessionEnd block | Vendored into the plugin; installed to `~/.claude/helpers/team-cleanup.sh` on plugin apply. |
| `status-reporter.sh` | 11 events: PreToolUse `*`, PreToolUse `AskUserQuestion`, PostToolUse `*`, UserPromptSubmit, SessionStart, SessionEnd, Stop, PreCompact `*`, SubagentStart, SubagentStop, PermissionRequest, Notification `idle_prompt` | `configs/claude/settings.json:273-500` (confirm actual range; see step 1 above) | Ships in the `db-agents-*.cjs` release bundle; plugin patches settings.json to reference the bundled path. |
| `auto-approve.sh` | PreToolUse `*` matcher | `configs/claude/settings.json:283-295` (confirm actual range) | Same as status-reporter: ships with db-agents. |

"Relevant only if the user opts into db-agents" applies to status-reporter and auto-approve -- both are db-agents integration hooks. If the user declines the db-agents step in the plugin skill, these entries are not added to settings.json.

## Bucket 2 -- Recommended / optional (documented, no installer support)

Functional but idiosyncratic. Adopt if curious; the plugin has no opinion.

- `hook-handler.cjs` -- my custom routing layer on top of Claude Code hooks. Dispatches to sub-handlers for `pre-bash`, `post-edit`, `route`, and several lifecycle events. Not required by the documented workflow; claude-mem's own hooks plus `team-cleanup.sh` cover the core behaviors.
- `intelligence.cjs`, `learning-service.mjs`, `learning-hooks.sh`, `learning-optimizer.sh`, `pattern-consolidator.sh` -- experimental learning / routing infra.
- `checkpoint-manager.sh`, `standard-checkpoint-hooks.sh` -- optional checkpoint automation.

## Bucket 3 -- Personal / not shareable

Listed for transparency. Plugin has zero opinion on these.

- Custom UI / terminal integrations: `statusline.cjs`, `tmux-pane-title.sh`, `tmux-session-end.sh`.
- Experimental daemons and monitors: the `swarm-*`, `v3-*`, `daemon-manager.sh`, `worker-manager.sh`, `health-monitor.sh`, `perf-worker.sh` families.
- Personal project conventions: `adr-compliance.sh`, `ddd-tracker.sh`, `v3.sh` and relatives.
- One-off automation: `auto-commit.sh`, `github-safe.js`, `github-setup.sh`, `security-scanner.sh`, `guidance-hook*.sh`, `quick-start.sh`, `setup-mcp.sh`.

The plugin's v0.1 skill checklist installs all of Bucket 1. Bucket 2 and Bucket 3 are documented here for transparency but receive no installer support -- now or in future versions.

Last verified against: Claude Code <X.Y.Z>, claude-mem <A.B.C>, db-agents <vP.Q.R> (2026-04-21).
```

Replace the `<X.Y.Z>` / `<A.B.C>` / `<vP.Q.R>` placeholders AND confirm the settings.json line ranges from step 1.

- [ ] **Step 4: Verify ASCII-only, word count, table, and footer**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-helpers.md
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/appendix-helpers.md
grep -c '^\[Back to README\]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-helpers.md
grep -c 'Last verified against' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-helpers.md
grep -c '^## Bucket [123]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-helpers.md
grep -c 'configs/claude/settings.json:' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-helpers.md
```

Expected: no non-ASCII, word count between 400 and 750 (target 500), Back-to-README count = 1, footer count = 1, bucket section count = 3, settings.json line-range citation count >= 2 (status-reporter + auto-approve, per spec Phase A success criterion).

- [ ] **Step 5: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/appendix-helpers.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): add appendix-helpers.md

Three-bucket helper categorization: Bucket 1 (required, installed by
v0.1 - team-cleanup plus db-agents integration hooks with
configs/claude/settings.json line-range citations), Bucket 2
(recommended/optional), Bucket 3 (personal/not shareable).

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 15: Write `appendix-databricks-tools.md`

Anchor: spec section 4.2 line 58. ~400w. Two topics: db-agents install + MCP recommendations.

**Files:**
- Create: `docs/claude-workflow/appendix-databricks-tools.md`

- [ ] **Step 1: Read the db-agents README to confirm the install commands**

```bash
sed -n '31,52p' /home/jon.gao/universe/experimental/richard-liu_data/db-agents/README.md
```

Record the exact `gh release download` commands and the port-forward instruction -- the appendix reproduces them verbatim.

- [ ] **Step 2: Create the appendix file**

Create `docs/claude-workflow/appendix-databricks-tools.md` with:

```markdown
[Back to README](README.md#9-minimum-viable-adoption)

# Appendix: Databricks-specific tooling

Two topics: the `db-agents` web dashboard (monitoring surface for long-running agent fleets) and the Databricks MCP stack recommendations (the plugin does NOT auto-configure these; the playbook documents them so teammates know which to enable).

## db-agents web dashboard

`db-agents` is a locally-hosted web dashboard for monitoring Claude Code sessions across repositories. See its README at `/home/jon.gao/universe/experimental/richard-liu_data/db-agents/README.md` for the canonical source.

**What it does.** Shows each running Claude Code session as an agent card with state (IDLE / BUSY / INPUT). Integrates diff review, markdown preview, file explorer, and git-stack browsing. Plays a light sound when an agent enters INPUT state so you can walk away.

**Install (from the db-agents README).**

```bash
tag=$(gh release list --repo databricks-eng/universe-dev --limit 20 | grep db-agents | head -1 | cut -f3)
gh release download "$tag" --repo databricks-eng/universe-dev --pattern "db-agents-*.cjs"
```

**Launch on Arca (requires Node 24).**

```bash
nvm use 24
node db-agents-*.cjs
```

**Port-forward from your Mac.** Add to `~/.ssh/config`:

```
Host arca.ssh
    LocalForward 13100 localhost:13100
```

Then open http://localhost:13100 in your browser.

**How the `claude-workflow-bootstrap` plugin handles this.** Item 5.4(f) of the plugin's interactive checklist runs the canonical install, lands the artifact under `~/.local/share/db-agents/`, writes a wrapper at `~/.local/bin/db-agents`, and patches `~/.claude/settings.json` with hook entries for `status-reporter.sh` / `auto-approve.sh` (which ship in the `.cjs` bundle). Skipped cleanly if you decline.

## Databricks MCP stack recommendations

The plugin does NOT configure MCP. These are the servers I recommend enabling for this workflow -- configuration comes from internal Databricks tooling.

- `devportal` -- PR details, CI run groups, test results, build logs. Essential for PR investigation work.
- `databricks-v2` -- SQL execution, notebooks, jobs, DBFS file access. Essential for any data work.
- `github` -- PR management (create, update, review). Complements `devportal` for the write side.
- `glean` -- internal documentation search. The right first stop for "how do we do X at Databricks."
- `claude-mem` -- local cross-session memory. Install as a plugin (`/plugin install claude-mem`); the MCP entry is auto-wired by the plugin.

Last verified against: Claude Code <X.Y.Z>, claude-mem <A.B.C>, db-agents <vP.Q.R> (2026-04-21).
```

Replace the version placeholders.

- [ ] **Step 3: Verify ASCII-only, word count, structure, and required content**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md
grep -c '^\[Back to README\]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md
grep -c 'Last verified against' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md
grep -c 'gh release download' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md
grep -c 'LocalForward 13100' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md
grep -c 'devportal\|databricks-v2\|github\|glean\|claude-mem' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md
```

Expected: no non-ASCII, word count between 320 and 600 (target 400), Back-to-README count = 1, footer count = 1, install command present, port-forward present, MCP list present.

- [ ] **Step 4: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/appendix-databricks-tools.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): add appendix-databricks-tools.md

db-agents install flow (canonical gh release download, Arca launch,
SSH port-forward) and Databricks MCP recommendations (devportal,
databricks-v2, github, glean, claude-mem). Explicit non-goal:
plugin recommends MCP but does not auto-configure.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 16: Write `appendix-skills.md`

Anchor: spec section 4.2 line 59. ~300w. Workflow-critical Superpowers skills, one-line purpose each.

**Files:**
- Create: `docs/claude-workflow/appendix-skills.md`

- [ ] **Step 1: Create the appendix file**

Create `docs/claude-workflow/appendix-skills.md` with:

```markdown
[Back to README](README.md#2-the-loop-in-one-picture)

# Appendix: Workflow-critical Superpowers skills

The `superpowers` plugin ships many skills; this appendix names only the ones this playbook depends on. For the complete list, see the `superpowers` plugin README.

## Phase skills (invoke in order)

- `superpowers:brainstorming` -- converts a fuzzy ask into a written spec. Skill is explicit that you MUST invoke it before creative work. Output lives at `docs/superpowers/specs/YYYY-MM-DD-<feature>-design.md`.
- `superpowers:writing-plans` -- converts a committed spec into bite-sized checkbox tasks. Output lives at `docs/superpowers/plans/YYYY-MM-DD-<feature>-plan.md`. Includes a self-review checklist (spec coverage, placeholder scan, type consistency).
- `superpowers:executing-plans` -- walks a plan task-by-task in the current session. Use when the plan is small enough to execute inline.
- `superpowers:subagent-driven-development` -- dispatches a fresh subagent per task with two-stage review between tasks. Use for anything non-trivial; the fresh context per task keeps any one agent from drifting.
- `superpowers:verification-before-completion` -- the rule-enforcer for HARD RULE 4. Invoke before any claim that work is complete, fixed, or passing.

## Supporting skills

- `superpowers:test-driven-development` -- write the failing test first, implement to green, commit. Use inside any implementation task.
- `superpowers:using-git-worktrees` -- creates isolated worktrees for concurrent agent work. The `claude-workflow-bootstrap` plugin's HARD RULES block already instructs you to pass `isolation: "worktree"` for concurrent edits; this skill handles the mechanics.
- `superpowers:systematic-debugging` -- invoke on any bug, test failure, or unexpected behavior BEFORE proposing fixes.
- `superpowers:dispatching-parallel-agents` -- when you face two or more independent tasks with no shared state.
- `superpowers:writing-skills` -- for creating new skills.

## Skills I intentionally do NOT use in this workflow

- `superpowers:execute-plan`, `superpowers:brainstorm`, `superpowers:write-plan` -- deprecated aliases of the `-ing` variants. Always prefer the current names.

Last verified against: Claude Code <X.Y.Z>, claude-mem <A.B.C>, db-agents <vP.Q.R> (2026-04-21).
```

Replace the version placeholders.

- [ ] **Step 2: Verify ASCII-only, word count, structure**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-skills.md
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/appendix-skills.md
grep -c '^\[Back to README\]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-skills.md
grep -c 'Last verified against' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-skills.md
grep -c '^- `superpowers:' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-skills.md
```

Expected: no non-ASCII, word count between 240 and 450 (target 300), Back-to-README count = 1, footer count = 1, skill-bullet count >= 9.

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/appendix-skills.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): add appendix-skills.md

Workflow-critical Superpowers skills with one-line purpose each:
phase skills (brainstorming, writing-plans, executing-plans,
subagent-driven-development, verification-before-completion) and
supporting skills (TDD, worktrees, debugging, parallel agents, writing-skills).

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 17: Write `appendix-agent-teams.md`

Anchor: spec section 4.2 line 60. ~600w. Deep dive on `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, TeamCreate/SendMessage/TaskUpdate, shutdown protocol, 3-section agent prompt template, Pipeline Context. Canonical reference for the three additions commit `1fb845a` made to HARD RULE 3.

**Files:**
- Create: `docs/claude-workflow/appendix-agent-teams.md`

- [ ] **Step 1: Read the current HARD RULE 3 verbatim to quote it correctly**

```bash
awk '/^\*\*3\. Team lifecycle/,/^\*\*4\./' /home/jon.gao/dotfiles/configs/claude/CLAUDE.md
```

The appendix must match this text.

- [ ] **Step 2: Create the appendix file**

Create `docs/claude-workflow/appendix-agent-teams.md` with:

```markdown
[Back to README](README.md#5-phase-3-execute-with-coordinator--teams)

# Appendix: Agent teams deep dive

This appendix is the canonical reference for agent-teams protocol. The README's section 5 is a summary; when a specific question comes up about how to spawn, coordinate, or shut down, look here.

## The feature flag

Agent teams are experimental. Enable by setting the env var in `~/.claude/settings.json`:

```json
"env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }
```

The `claude-workflow-bootstrap` plugin sets this for you as part of item 5.4(b) of its install checklist.

## The core tools

- `TeamCreate` -- creates a named team. You are the lead by default.
- `TeamDelete` -- tears down a team. Defensive call before `TeamCreate` because `TeamCreate` fails with "Already leading team" if a prior run left one behind.
- `Agent(name, team_name, run_in_background=true)` -- spawns a teammate in the named team. `run_in_background=true` is a HARD RULE; waiting synchronously for an agent defeats parallelism.
- `SendMessage(to, message)` -- routes a message to a named teammate (or `"*"` for broadcast).
- `TaskCreate` / `TaskUpdate` / `TaskList` -- the task board. Status flows via `TaskUpdate`; findings flow via `SendMessage`.

## Spawn sequence

```
TeamDelete (defensive)
  -> TeamCreate(team_name)
  -> TaskCreate(task description)
  -> Agent(name, team_name, run_in_background=true, prompt=<3-section template>)
```

Retry `TeamCreate` once on failure; if it returns "Already leading team", call `TeamDelete` first.

## The 3-section agent prompt template

Every agent prompt has three sections in this order:

```
## PRE_TASK
Pipeline context (if any) is inlined under **Pipeline Context** below.

## TASK
[Pipeline Context, Role, Task, Diff Context]

## POST_TASK
End with a ## RESULTS block:
## RESULTS
- **Status**: completed | partial | blocked
- **Files Changed**: list or "none"
- **Key Findings**: ALL discoveries, decisions, output

RULES: Do NOT spawn agents -- request via coordinator. In git repos, git writes happen only inside your assigned worktree; no branch switching inside a worktree.
```

Pipeline Context is the coordinator's ONLY reliable channel for passing prior agent output into the next agent. Inline the content; do not pass references. See HARD RULE 3 in `configs/claude/CLAUDE.md` for the authoritative spec.

## Shutdown protocol

Lead sends `{type: "shutdown_request"}` via `SendMessage` to each teammate. Teammate replies `{type: "shutdown_response", approve: true}` only after verifying all of:

- No pending or in_progress tasks still owned by them.
- All their edits are saved/committed (worktree clean or handed off).
- All key findings have been sent via `SendMessage`.

If any check fails, the teammate replies `approve: false` with a `reason`, finishes the outstanding work, then signals readiness. Lead retries `shutdown_request`. After every teammate approves, the lead calls `TeamDelete`.

## The three HARD RULE 3 additions from commit `1fb845a`

Commit `1fb845a docs(claude): allow disk-read of team inbox files as SendMessage workaround` added three things to HARD RULE 3 that are load-bearing for correctness:

**1. The reliability caveat.** `SendMessage` is not guaranteed. Claude Code issues #43706, #38932, #42999 can silently drop messages in either direction. Never assume a message went through just because `SendMessage` returned success.

**2. The disk-verification escape hatch.** The persisted inbox files at `~/.claude/teams/{team-name}/inboxes/{teammate-name}.json` (plus the lead's own `team-lead.json`) are the source of truth. Reading them directly to verify delivery is permitted and is not considered polling.

**3. The shutdown verification requirement.** Before concluding a teammate is unresponsive or retrying `shutdown_request`, the lead MUST read both the lead's own inbox file and the teammate's inbox file on disk to check for a persisted `shutdown_response` or findings that in-band delivery missed. Act on whatever is on disk; do not re-send if the response is already persisted.

Prescriptive behavior update that came with the commit: wait for `SendMessage`; do not poll teammates in-band (no status-check DMs, no `TaskList` spam). Disk reads for verification are permitted and are not considered polling.

This is exactly the "protocols are lossy, practices carry you through" thesis from README section 10. The protocol (TeamCreate / SendMessage / TaskUpdate) did not change; the delivery layer did, and HARD RULE 3 absorbed that reality.

Last verified against: Claude Code <X.Y.Z>, claude-mem <A.B.C>, db-agents <vP.Q.R> (2026-04-21).
```

Replace the version placeholders.

- [ ] **Step 3: Verify ASCII-only, word count, and required content**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
grep -c '^\[Back to README\]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
grep -c 'Last verified against' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
grep -c '1fb845a' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
grep -c '#43706\|#38932\|#42999' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
grep -c 'inboxes/' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
grep -c 'shutdown_request\|shutdown_response' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
grep -c 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-agent-teams.md
```

Expected: no non-ASCII, word count between 480 and 900 (target 600), Back-to-README count = 1, footer count = 1, `1fb845a` citation count >= 1, issue number count >= 1 (or 3 matches on one line is fine), inbox path count >= 1, shutdown keyword count >= 1, env var count >= 1.

- [ ] **Step 4: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/appendix-agent-teams.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): add appendix-agent-teams.md

Canonical reference for agent-teams protocol. Covers the feature flag,
the core tools (TeamCreate/SendMessage/TaskUpdate), spawn sequence,
3-section agent prompt template, shutdown protocol, and the three
HARD RULE 3 additions from commit 1fb845a (reliability caveat,
disk-verification escape hatch, shutdown verification requirement).

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 18: Write `appendix-verification.md`

Anchor: spec section 4.2 line 61. ~300w. Concrete examples of verify-before-claim: good evidence vs. bad, how to cite subagent-reported findings, how to retract gracefully.

**Files:**
- Create: `docs/claude-workflow/appendix-verification.md`

- [ ] **Step 1: Create the appendix file**

Create `docs/claude-workflow/appendix-verification.md` with:

```markdown
[Back to README](README.md#6-phase-4--verify)

# Appendix: Verification examples

HARD RULE 4 in `configs/claude/CLAUDE.md` is abstract ("every factual assertion needs direct evidence"). This appendix is the concrete version.

## Good evidence

**File:line citation.** "The parser skips blank lines at `src/parse.py:47-52`." I can point at `src/parse.py:47` and the behavior is right there.

**Command output with the last-line summary.** "Tests pass: `pytest -x tests/test_parse.py` -> `===== 23 passed in 1.24s =====`." I ran the command; the output is the receipt.

**Subagent-reported citation.** A dispatched agent reports "Root cause: `src/parse.py:47` skips the header row because the guard at line 45 returns early when `isheader(row)`." That counts as evidence -- I do not redundantly re-read `src/parse.py` myself.

## Bad evidence (these are rule violations)

**Reasoning dressed as fact.** "The test probably fails because X." "Probably" is the tell. Retract or verify.

**Pattern-matching.** "This usually happens when Y." "Usually" is the tell. Retract or verify.

**Name-dropping without reading.** "The `parse_line` function has a bug." If I have not read `parse_line`, I am bluffing. Retract or verify.

**Trusting a CI badge on GitHub without checking which commit it reflects.** The badge might be green for `main`; my branch might be red. Retract or re-verify against my branch.

## How to retract gracefully

If I already asserted something and now realize I cannot back it up, the retraction goes in the next message I send, not buried in a follow-up paragraph. Example:

> Correction on my previous message: I said the handler was in `src/http.py`. I have not verified that. Checking now.

Then I verify, paste the receipt, and continue. The goal is to train my future self and my reader: the cost of retracting is low; the cost of a false assertion compounding into a design decision is high.

## Subagent citation rules

When a subagent reports `file:line` with a snippet in its RESULTS block, that counts as evidence for me as the coordinator. I do not re-verify. If the subagent reports a conclusion without `file:line`, I either ask for the citation or dispatch a verification agent -- I do not accept it as evidence by default.

Last verified against: Claude Code <X.Y.Z>, claude-mem <A.B.C>, db-agents <vP.Q.R> (2026-04-21).
```

Replace the version placeholders.

- [ ] **Step 2: Verify ASCII-only, word count, structure**

```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-verification.md
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/appendix-verification.md
grep -c '^\[Back to README\]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-verification.md
grep -c 'Last verified against' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-verification.md
grep -c '^## Good evidence\|^## Bad evidence\|^## How to retract\|^## Subagent citation' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-verification.md
```

Expected: no non-ASCII, word count between 240 and 450 (target 300), Back-to-README count = 1, footer count = 1, required section count = 4.

- [ ] **Step 3: Commit**

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/appendix-verification.md
git commit -m "$(cat <<'EOF'
docs(claude-workflow): add appendix-verification.md

Concrete examples for HARD RULE 4: good evidence (file:line citation,
command output, subagent RESULTS citation), bad evidence (reasoning /
pattern-matching / name-dropping / trusting CI badge), how to retract
gracefully, subagent citation rules.

Co-authored-by: Isaac
EOF
)"
```

Expected: commit succeeds.

---

## Task 19: Verify all cross-links and Phase A success criteria

This task has no file writes. It runs the final validation and fixes any issues found.

- [ ] **Step 1: Verify every appendix has a "Back to README" link**

```bash
for f in /home/jon.gao/dotfiles/docs/claude-workflow/appendix-*.md; do
  if ! head -1 "$f" | grep -q '^\[Back to README\]'; then
    echo "MISSING back-link: $f"
  fi
done
echo "back-link check done"
```

Expected: only `back-link check done`. If any MISSING lines appear, add a `[Back to README](README.md#...)` line at the top of that file and commit the fix.

- [ ] **Step 2: Verify every appendix is referenced from the README at least once**

```bash
for f in appendix-claude-md appendix-helpers appendix-databricks-tools appendix-skills appendix-agent-teams appendix-verification; do
  count=$(grep -c "$f" /home/jon.gao/dotfiles/docs/claude-workflow/README.md)
  echo "$f: $count README mentions"
done
```

Expected: every appendix has at least 1 README mention. If any show 0, add a reference in the most appropriate README section and commit the fix.

- [ ] **Step 3: Verify README anchor links match the section headings they reference**

```bash
grep -oE '\(#[0-9a-z-]+\)' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-*.md | sort -u
grep -E '^## [0-9]+\.' /home/jon.gao/dotfiles/docs/claude-workflow/README.md
```

GitHub-flavored markdown generates anchors by lowercasing, replacing spaces with hyphens, and stripping punctuation except hyphens. For each `(#...)` anchor used in an appendix back-link, confirm the README has a heading that matches. Known mappings:

- `#5-phase-3-execute-with-coordinator--teams` -> README heading `## 5. Phase 3 -- Execute with coordinator + teams`
- `#6-phase-4--verify` -> README heading `## 6. Phase 4 -- Verify`
- `#9-minimum-viable-adoption` -> README heading `## 9. Minimum viable adoption`
- `#2-the-loop-in-one-picture` -> README heading `## 2. The loop in one picture`

If any anchor does not resolve, fix the appendix link and commit.

- [ ] **Step 4: Full-file ASCII sweep across every new file**

```bash
for f in /home/jon.gao/dotfiles/docs/claude-workflow/*.md; do
  out=$(LC_ALL=C grep -n '[^[:print:][:space:]]' "$f")
  if [ -n "$out" ]; then
    echo "NON-ASCII in $f:"
    echo "$out"
  fi
done
echo "ASCII sweep done"
```

Expected: only `ASCII sweep done`. If any NON-ASCII lines appear, fix with `sed` or re-write the offending text and commit.

- [ ] **Step 5: Footer presence on every appendix**

```bash
for f in /home/jon.gao/dotfiles/docs/claude-workflow/appendix-*.md; do
  if ! grep -q 'Last verified against' "$f"; then
    echo "MISSING footer: $f"
  fi
done
echo "footer check done"
```

Expected: only `footer check done`.

- [ ] **Step 6: Phase A success criteria from spec section 6**

Check each:

```bash
# 1. Every appendix reachable from README and links back
# (already verified in steps 1-2 above)

# 2. appendix-helpers.md renders the three-bucket table with Bucket 1 settings.json citations
grep -c 'Bucket [123]' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-helpers.md
grep -c 'configs/claude/settings.json' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-helpers.md

# 3. appendix-databricks-tools.md describes db-agents install flow and lists MCP servers
grep -c 'gh release download' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md
grep -E 'devportal|databricks-v2|github|glean|claude-mem' /home/jon.gao/dotfiles/docs/claude-workflow/appendix-databricks-tools.md | wc -l

# 4. No references to unreleased plugin features
# This is a manual review -- read each file and confirm any plugin mention
# (claude-workflow-bootstrap, superpowers, claude-mem, plugin-builder, pr-review-toolkit,
#  commit-commands) is described as "install via /plugin install ..." or "the plugin does X",
# not as "will do X in a future version" or "TBD".
grep -rn 'TBD\|TODO\|FIXME\|v0\.2\|coming soon\|not yet implemented' /home/jon.gao/dotfiles/docs/claude-workflow/
```

Expected:
- Bucket count = 3.
- settings.json citation count >= 2.
- `gh release download` count >= 1.
- MCP server mention count >= 5.
- TBD/TODO/FIXME/v0.2/etc. scan returns no hits (or only hits inside intentional strings, which you review by eye).

- [ ] **Step 7: Final sanity -- total word counts**

```bash
echo "README:"
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/README.md
echo "Appendices:"
wc -w /home/jon.gao/dotfiles/docs/claude-workflow/appendix-*.md
```

Expected:
- README between 2200 and 3500 (target 2750).
- Each appendix within its +/-20% target band (see table at top of plan).

- [ ] **Step 8: Commit fixes if any were applied**

If any of the above steps required edits, commit them as one fix-up:

```bash
cd /home/jon.gao/dotfiles
git add docs/claude-workflow/
git commit -m "$(cat <<'EOF'
docs(claude-workflow): fix cross-link and validation issues

Post-authoring sweep caught [describe issues found, e.g.,
missing back-link in appendix-X, stale anchor in appendix-Y,
non-ASCII character in Z]. Fixed inline.

Co-authored-by: Isaac
EOF
)"
```

If no fixes were needed, skip this step.

- [ ] **Step 9: Open the README in a renderer one last time**

Either:

```bash
glow /home/jon.gao/dotfiles/docs/claude-workflow/README.md
```

or push to a scratch branch and view on GitHub. Read the whole thing. Any sentence you catch yourself skimming is a candidate for compression; any sentence you cannot parse on first read is a bug. Do one final pass to fix those and commit as a "docs(claude-workflow): prose polish" commit if warranted.

---

## Phase A exit criteria

The plan is done when:

- [ ] All 7 files exist under `docs/claude-workflow/` with the word counts from the table at the top of this plan.
- [ ] Task 19's six verification steps pass (steps 1-7 green, step 8 either skipped or committed).
- [ ] `git log --oneline docs/claude-workflow/` shows one commit per task (Tasks 1-18) plus optional fix-up commits.
- [ ] No unstaged changes in `docs/claude-workflow/` (`git status --short docs/claude-workflow/` empty).

When all four are true, Plan A is complete. Phase B (plugin scaffold) and Phase C (SKILL.md interactive flow + install scripts) are separate plans -- not part of Plan A.
