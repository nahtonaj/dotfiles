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
