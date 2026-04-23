# Claude Workflow Playbook

A first-person walkthrough of how I run Claude Code day-to-day at Databricks. The loop is brainstorm, plan, execute, verify, and the mechanics are coordinator-plus-agent-teams. Fourteen sections, roughly 5100 words, skimmable in under 45 minutes.

Target reader: a Databricks engineer who already has Claude Code installed and wants a more structured workflow than ad-hoc prompting.

## Table of contents

1. [Why this doc](#1-why-this-doc)
2. [The loop in one picture](#2-the-loop-in-one-picture)
3. [Phase 1 -- Brainstorm](#3-phase-1----brainstorm)
4. [Phase 2 -- Plan](#4-phase-2----plan)
5. [Phase 3 -- Execute with coordinator + teams](#5-phase-3----execute-with-coordinator--teams)
6. [Phase 4 -- Verify](#6-phase-4----verify)
7. [Commit, remember, move on](#7-commit-remember-move-on)
8. [CLAUDE.md strategy](#8-claudemd-strategy)
9. [Persistence: tmux + db-agents](#9-persistence-tmux--db-agents)
10. [Coordinator + agent teams strategy](#10-coordinator--agent-teams-strategy)
11. [Parallelization playbook](#11-parallelization-playbook)
12. [Common failure modes](#12-common-failure-modes)
13. [Minimum viable adoption](#13-minimum-viable-adoption)
14. [Living with a moving target](#14-living-with-a-moving-target)

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

Section 2 shows the loop as a single picture. Sections 3-7 walk each phase. Sections 8-11 are the strategy layer: how I think about CLAUDE.md, how I stay resilient across SSH drops and reboots, how I decide between coordinator-direct vs. single-agent vs. full-team, and the four parallelization patterns I actually use. Section 12 is the catalog of mistakes I still make when I get lazy. Section 13 is the minimum-viable path for someone who wants to try one piece at a time. Section 14 is the mindset for keeping this doc useful as Claude Code evolves -- practices persist, protocols do not.

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

---

## 7. Commit, remember, move on

The tail of the loop is three actions I do every time, not just when I feel like it.

**Commit via `commit-commands:commit-push-pr`.** The skill handles the body format, co-author trailer, and (optionally) pushing and opening a PR. I use the `commit-commands:commit` variant when I want to commit without pushing. The point of using the skill instead of running `git commit` directly is consistency -- commit messages are the part of the repo history I read most and the one most likely to rot when I hand-roll them.

**Remember via `claude-mem`.** The `claude-mem` plugin has a Stop hook that captures the session into cross-session memory. I do nothing; the plugin runs on session end. Later sessions query that memory via `claude-mem:mem-search` ("did we already solve this?") and `claude-mem:knowledge-agent` ("what do I know about X?"). The critical property is that memory is cross-session, not cross-repository -- the plugin scopes observations to the current working directory by default.

**PR review via `pr-review-toolkit:review-pr`.** When I open a PR, I run the review skill as a sanity check before asking a human. It is a cheap second pair of eyes.

Then I close the Claude Code session and move on. The next time I open a session in this repo, claude-mem primes context automatically -- I do not re-explain what I was working on.

---

## 8. CLAUDE.md strategy

CLAUDE.md is the policy layer that makes the rest of this loop enforceable. There are two layers I maintain: `~/CLAUDE.md` (global, applies to every Claude Code session on this machine) and `<repo>/CLAUDE.md` (project-local, committed with the repo). Both auto-inject into every session, which is why they need to stay lean and load-bearing.

**Why the HARD RULES are rules, not suggestions.** The top of `~/CLAUDE.md` has four numbered HARD RULES in caps-lock with "zero tolerance" language. Each rule exists because I kept making the same specific mistake until I codified it. The rules stop reading like rules the moment I soften them, so I do not soften them. Rule 1 excerpted verbatim:

```markdown
## HARD RULES

**1. Delegate implementation work to agents.**
For any file editing, writing, multi-step research, or implementation,
spawn an agent. Direct tool use is for trivial one-call read-only ops only.

Coordinator may use blocked tools directly ONLY for:
- Reading one file to answer a factual question
- Running one grep/glob/bash status check (git status, port check, ls)
- Any single read-only call completing in seconds
```

The full walkthrough of all four rules is in `appendix-claude-md.md`.

**Two-layer pattern: global vs. project.** Global rules are about how I drive Claude Code -- agent protocols, verification discipline, ASCII preference. They travel with me to any repo. Project rules are about this particular codebase. Rule of thumb: guidance that survives cloning the repo to a new machine goes project-local; guidance that survives switching to a different repo goes global. From `dotfiles/CLAUDE.md` Conventions, verbatim:

```markdown
## Conventions

- Config source files live in `configs/`, NOT directly in the repo root
- macOS-only modules go in `nix/modules-darwin/`
- `flakePath` refers to the repo root in Nix expressions
```

None of those lines is portable; all are essential inside this repo. The global rules say nothing about Nix because nothing about Nix travels to other repos.

**Precedence.** When the rules collide, the order is: explicit user instruction in this turn > CLAUDE.md rules > skill instructions > default system behavior. The "Precedence" block in `~/CLAUDE.md` makes this explicit so I can point to it when someone asks why Claude Code ignored a skill default.

**Evolution policy.** A rule earns its place by causing a painful failure mode at least twice. Preferences ("ASCII only", "batch independent tool calls", terse conversational register) accrete more loosely. Rules get retired when Claude Code changes the underlying tool surface enough that the rule is protecting a thing that no longer exists. The "Living with a moving target" mindset from section 14 applies inward: I do not pin rules to a specific protocol version.

**Memory is separate.** CLAUDE.md is policy; `claude-mem` auto-memory at `~/.claude/projects/*/memory/MEMORY.md` is history. Do not mix them. When I catch myself wanting to write a "remember this for next time" note into CLAUDE.md, that is a signal it belongs in memory instead.

See `appendix-claude-md.md` for the rules walkthrough and the rationale for the specific four HARD RULES.

---

## 9. Persistence: tmux + db-agents

Claude Code runs on a remote dev host (Arca) over SSH. SSH drops are routine; browser tabs crash; the laptop suspends. Persistence is what lets me tolerate all three without losing session state.

**The threat model.** An uninterrupted 4-hour coordinator session is fictional. In reality the network flakes three times, the laptop lid closes once, and the Arca host restarts for a security update sometime during the week.

**Layer one: tmux for the interactive session.** My Linux zshrc auto-starts tmux on login. From `configs/zsh/zshrc.linux:8-11`:

```zsh
if [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
    command -v tmux >/dev/null && tmux -A
fi
```

`tmux -A` attaches to the default session or creates it. First SSH login creates session `default`; every subsequent login reattaches. The Claude Code CLI runs inside that session. When SSH drops, the CLI keeps running; when I reconnect, scrollback is intact.

**Layer two: per-agent tmux-backed PTYs via db-agents.** `db-agents` spawns every teammate inside its own tmux session named `db-agent-*`. Each agent's turn-by-turn state lives in that tmux buffer. When the `db-agents` daemon restarts (for example after the Arca host reboots), it rediscovers those sessions and re-binds bookkeeping to maintain PTY proxy consistency. The agent does not restart; the proxy does.

**Port-forward.** The dashboard serves `:13100` on Arca. From my laptop:

```bash
# ad-hoc, once per laptop session
arca et -t 13100

# or persistent, in ~/.ssh/config for the arca host
# LocalForward 13100 localhost:13100
```

Dashboard at `http://localhost:13100` shows each agent's state (IDLE / BUSY / INPUT) and lets me intervene without opening ten Claude Code panes.

**Recovery drill: SSH drops, you come back.**

```bash
# laptop reconnects after dropped link / lid close / hotel wifi flake
ssh arca

# zshrc auto-runs `tmux -A` for you, reattaching session "default"
# the Claude Code CLI is still running in its pane, mid-turn if needed
# scrollback survived; no context re-explanation needed

# (in another laptop pane, re-forward if it dropped)
arca et -t 13100

# dashboard at http://localhost:13100 still shows the in-flight team
# with live per-agent state -- db-agents daemon never died
```

No team respawn. No re-priming of context.

**Where persistence stops helping.** The agent process itself dying. When an agent crashes mid-edit on a permission prompt, its tmux pane is gone; tmux has nothing to restore. Recovery then falls to the coordinator: finish the work directly, surgically remove the dead member from the team's `config.json` so `TeamDelete` can proceed, note the detour in the commit. Persistence saves you from a dead transport, not a dead process.

See `appendix-databricks-tools.md` for the db-agents install walkthrough and the port-forward details.

---

## 10. Coordinator + agent teams strategy

Section 5 and `appendix-agent-teams.md` cover the mechanics. This section is the question that comes earlier: given a task, do I spawn a full team, a single agent, or just do it myself?

**The three-way decision.**

*Coordinator direct.* One read or one bounded edit, no multi-step research, no permissions surface. Example -- a factual status check the coordinator runs inline rather than spawning:

```bash
grep -n 'parse_metric_key' src/handlers.py
```

One read, one line of output, no follow-up. Spawning an agent for that is waste. The other direct-execution case is the permission-prompt escape hatch: when a delegated agent crashes mid-edit on a dialog and the remaining work is a small substitution, the coordinator applies it directly. Earned by failure, not free license. When `dotfiles-ascii-patcher` crashed on a permission dialog mid-task, I applied the six em-dash replacements directly and recorded why in commit `ae5978c`. The next three tasks went back to full delegation.

*Single agent, no team.* Explore/Glob/Grep for a read-only lookup. HARD RULE 2 explicitly allows this one exception:

```
Agent({
  subagent_type: "Explore",
  description: "callsite survey",
  prompt: "Find every callsite of `parse_metric_key` in `src/` and report file:line plus 3 lines of surrounding context."
})
```

No `team_name`, no shutdown protocol. Anything that might produce an edit stays in a team even if only one agent runs, because I want the shutdown handshake and inbox-file verification.

*Full team with a lead.* The default. Any file edit, any multi-step research, any spawn that might beget a second spawn. The three-call spawn shape:

```
TeamDelete({team_name: "fix-migration"})         # defensive cleanup
TeamCreate({team_name: "fix-migration"})
TaskCreate({title: "Patch migration 0042 backfill"})
Agent({
  name: "coder",
  team_name: "fix-migration",
  subagent_type: "backend-dev",
  run_in_background: true,
  prompt: "Edit migrations/0042_user_schema.sql so the backfill runs in batches of 10k rows..."
})
```

Named team, named agent, explicit `shutdown_request` / `shutdown_response` handshake, `TeamDelete` at the end.

**Why the coordinator stays lightweight even for a one-agent team.** Context economy. Every token I spend reading a file is a token I cannot spend deciding what the next agent does. When I violate "coordinator stays lightweight" it is always gradual -- one harmless read leads to a second, and fifteen tool calls later I have forgotten which teammate is waiting on which handoff.

**Team shapes I have actually run.**

- *Sole-coder team.* One coder, several follow-up agents. Useful when the spec fits in one head but the follow-ups (build, test, commit, review) fan out.
- *Dual-worktree team.* Two coder agents, each in its own worktree, each in its own repo. A recent session had `plugin-coder` shipping a 21-commit branch in the plugin marketplace while `dotfiles-ascii-patcher` fixed em-dashes in dotfiles.
- *Investigator plus antagonist.* Detailed in section 11.1.

See `appendix-agent-teams.md` for the protocol details.

---

## 11. Parallelization playbook

Four named patterns. Each one I have run at least once; each names when to use it, the shape of the team, and a concrete example.

### 11.1 Antagonist investigation

*When.* Root-cause debugging with two or more plausible hypotheses. Single-investigator failure mode: confirmation bias on the first hypothesis that fits.

*Shape.* Two read-only agents. Investigator emits ranked hypotheses; antagonist tries to falsify each one.

```
# investigator -- produce ranked candidates
Agent({
  name: "investigator",
  team_name: "rca-sc227980",
  prompt: "Read the alert config at configs/prometheus/probes.yaml and the probe code at src/probes/ingestion_kafka.go. Produce a ranked list of candidate root causes for the observed alert spike, each paired with the specific evidence you would collect to confirm it."
})

# antagonist -- refute or flag under-evidenced (spawned with investigator findings in Pipeline Context)
Agent({
  name: "antagonist",
  team_name: "rca-sc227980",
  prompt: "For each candidate hypothesis in <investigator findings inlined>, produce evidence that rules it out, or flag the candidate as under-evidenced. Assume the investigator is wrong until proven otherwise."
})
```

*Example.* SC-227980 presented three candidates -- probe over-emission, pod restart artifacts, Prometheus counter resets -- each refuted by evidence before the real cause (an M3 query-layer phantom read) was accepted. Running antagonist-first meant I committed no code to the wrong fix.

*Why it works.* An explicit skeptic role with a refutation-only brief suppresses the confirmation-bias default.

### 11.2 Build / test / commit-push / review fan-out

*When.* A coder agent has just finished an implementation. The follow-ups have no mutual dependencies.

*Shape.* Four parallel agents, spawned in a single coordinator message:

```
# one coordinator message, four Agent calls in parallel
Agent(subagent_type="general-purpose", name="build-validator",
      team_name="ship-v2", isolation="worktree",
      prompt="Run `make build` and report the last 20 lines of output plus exit code.")

Agent(subagent_type="general-purpose", name="test-runner",
      team_name="ship-v2", isolation="worktree",
      prompt="Run `make test` and report pass/fail counts and any stderr.")

Agent(subagent_type="general-purpose", name="committer",
      team_name="ship-v2", isolation="worktree",
      prompt="Use commit-commands:commit-push-pr to commit and push the current branch; report the PR URL.")

Agent(subagent_type="general-purpose", name="reviewer",
      team_name="ship-v2", isolation="worktree",
      prompt="Invoke pr-review-toolkit:review-pr on the newly-opened PR; report the summary.")
```

*Example.* The recent `claude-workflow-bootstrap` PR ran that tail sequentially inside one agent. The next plugin I ship will fan it out -- build and test are each several minutes and share no state with commit ordering or review.

*Why it works.* Build, test, commit, and review are mutually orthogonal; serial execution is pure wall-clock waste.

### 11.3 Specialization via narrow scope

*When.* Any task big enough that a generalist agent would swing across unrelated domains. Cross-repo work is the cleanest case.

*Shape.* One agent per concern, each scoped to a single repo and a narrow skill set.

```
# two agents, two repos, one team -- pattern from a real cross-repo ship
Agent(name="plugin-coder",
      team_name="plugin-ship", isolation="worktree",
      prompt="Work in /home/jon.gao/plugin-marketplace. Ship the bootstrap plugin branch. Skills: superpowers:subagent-driven-development, plugin-builder:plugin-self-review, commit-commands:commit.")

Agent(name="dotfiles-ascii-patcher", subagent_type="dotfiles-editor",
      team_name="plugin-ship", isolation="worktree",
      prompt="Work in /home/jon.gao/dotfiles. Replace em-dashes in configs/claude/team-cleanup.sh with `--`. Commit via commit-commands:commit.")
```

Neither agent can touch the other's repo; neither needs to. When one got stuck on a permission prompt, replacement was cheap because the scope was already small.

*Why it works.* Narrow scope shrinks the permission surface, keeps context small, and makes replacement cheap. The upstream-first fix pattern composes naturally: one agent patches the source while another proceeds on disjoint downstream work.

### 11.4 Skills and plugins as composition API

*When.* Whenever the right skill exists for a subtask, the coordinator picks the skill for the role instead of hand-rolling the work.

*Shape.* Each agent receives a named skill or plugin chain as its primary tool.

```
Agent(name="feature-doer", team_name="feature-x",
      prompt="""
  1. Invoke superpowers:brainstorming to produce the spec.
  2. Hand off to superpowers:writing-plans for the plan.
  3. Execute via superpowers:subagent-driven-development.
  4. Commit with commit-commands:commit-push-pr.
""")
```

*Example.* The bootstrap-plugin session composed `superpowers:subagent-driven-development` (execution discipline), `plugin-builder:plugin-self-review` (marketplace compliance validation), and `commit-commands:commit` (commit-message format). I did not re-derive any of the three; composition was nearly free.

*Why it works.* Skills encode other people's lessons. Coordinator taste -- which skills match which roles -- is the leveraged part; skill internals are not my problem.

See `appendix-skills.md` for the specific Superpowers skills this playbook depends on and `appendix-agent-teams.md` for the spawn/coordinate/shutdown protocol.

---

## 12. Common failure modes

These are the mistakes I still make, organized by symptom. When a session is going wrong, I check this list before anything else.

**Coordinator doing heavy work.** I open a file "just to check one thing" and half an hour later I am eight tool calls deep into a diff. Symptom: I cannot remember what the teammate is waiting for. Fix: stop, send the teammate a status update from whatever partial state I have, and delegate the open thread.

**Agent spawn without `team_name`.** The spawn succeeds but `SendMessage` fails silently because there is no team to route through. Symptom: my teammate is "running" but never responds. Fix: `TeamDelete`, respawn with `team_name` set.

**Skipping brainstorm.** I jump straight to writing a plan because the problem "seems obvious." Symptom: halfway through execution I realize two of the constraints contradict. Fix: pause, invoke `superpowers:brainstorming`, produce a spec, resume.

**Claiming "tests pass" without running them.** HARD RULE 4 violation. Symptom: the PR lands and CI fails. Fix: always run the verification command and paste the last line of output.

**Over-sharing between agents.** I include ten thousand lines of prior context in every agent prompt "just to be safe." Symptom: agents run out of context mid-task and their edits become erratic. Fix: trust the Pipeline Context heading -- if agent N+1 does not need agent N's output verbatim, summarize.

**Polling teammates in-band.** I send `SendMessage` status-check DMs because I am impatient. Symptom: teammate inboxes fill with meta-messages that drown the real findings. Fix: read the persisted inbox file on disk (`~/.claude/teams/{team-name}/inboxes/*.json`) -- HARD RULE 3 explicitly permits this as verification, not polling.

---

## 13. Minimum viable adoption

The full loop is a lot to adopt at once. Here is the graduated path I recommend for a Databricks teammate going from zero to steady state. Each step has a one-line success check -- if the check passes, move on; if it does not, fix before proceeding.

**Step 1 -- Install the bootstrap plugin.**

```bash
/plugin install claude-workflow-bootstrap
```

Success check: `claude-workflow-bootstrap` appears in `/plugin list`.

The plugin lives at `plugin-marketplace/experimental/teams/eng-ingestion/claude-workflow-bootstrap/`. It configures your `~/.claude/CLAUDE.md` with HARD RULES, sets `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, installs the team-cleanup hook, and installs the db-agents binary + its integration hooks. See `appendix-databricks-tools.md` for what db-agents does and `appendix-claude-md.md` for the HARD RULES walkthrough.

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

**Step 6 -- Read the failure-modes list (section 12) one more time.**

You will repeat at least three of those mistakes in your first week. Having already seen them listed makes the debugging shorter.

Success check: you catch yourself about to violate a HARD RULE, pause, and course-correct without being told.

---

## 14. Living with a moving target

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
