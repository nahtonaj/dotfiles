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

---

## 3. Phase 1 -- Brainstorm

Open a Claude Code session and invoke `superpowers:brainstorming` before you write anything. The skill is explicit that you MUST run it before creative work; I treat that as literal. The skill reads your initial ask and interrogates the design space before any code or plan is produced.

**What a good input looks like.** One paragraph naming the user-visible outcome plus two or three constraints that are already load-bearing. Examples of load-bearing constraints: "must ship as a Claude Code marketplace plugin", "must work without the universe repo checkout", "under a hundred lines of SKILL.md". Examples of things that are not load-bearing: specific file paths I intend to touch, naming conventions, testing framework choices. Those belong in the plan, not the brainstorm.

**Signals that you have enough to stop.** The brainstorming output is a written spec with a Summary, Goals / Non-goals, concrete deliverables, open questions, and an "out of scope" section. When I can read that spec and imagine a plan-writing teammate going from there to checkbox tasks without asking me clarifying questions, brainstorming is done. If open questions materially block the plan, resolve them first -- they are not Plan-A work.

**Where the spec lives.** `docs/superpowers/specs/YYYY-MM-DD-<feature>-design.md`, one file per brainstorm output. Commit it before moving to planning, even if it is still draft-status. The reason: the plan-writer reads the spec verbatim; if the spec is not committed, the plan references a moving target.

See `appendix-claude-md.md` for the HARD RULES that govern how the coordinator delegates during the brainstorm (short version: I do not write the spec myself -- a subagent does, and I review).

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

---

## 6. Phase 4 -- Verify

Verification is HARD RULE 4 in `configs/claude/CLAUDE.md` and it is the rule I break most often when tired. I invoke `superpowers:verification-before-completion` before any claim that work is complete, fixed, or passing.

**Evidence is file:line citations plus command output.** Not reasoning. Not pattern-matching on how things "usually go". Not "the error message suggests". Reading the code that produces the behavior, pasting the output of the test, naming the exact line where the assertion lives.

**Zero tolerance for unverified claims.** A single assertion made without evidence is a rule violation. This sounds extreme and is extreme, and the reason it has to be extreme is that one unverified claim buried in a PR comment trains the reader to trust the other ninety. If I cannot cite evidence, I retract -- "I suspect but have not confirmed" is better than "this fails because Z" with no receipt.

**Where I use this explicitly.** Before saying "tests pass" in any status message, I run the tests and paste the last line. Before writing "root cause" in a PR description, I cite the file:line that produces the behavior. Before approving a shutdown_request from a teammate, I verify their RESULTS block against the actual diff they produced. Subagent-reported citations with file:line snippets count as evidence and I do not redundantly re-verify.

Concrete examples of good vs. bad evidence in `appendix-verification.md`.
