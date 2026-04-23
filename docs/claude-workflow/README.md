# Claude Workflow Playbook

A first-person walkthrough of how I run Claude Code day-to-day at Databricks. The loop is brainstorm, plan, execute, verify, and the mechanics are coordinator-plus-agent-teams. Fourteen sections, roughly 5200 words, skimmable in under 45 minutes.

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

CLAUDE.md is the policy layer that makes the rest of this loop enforceable. There are two layers I actually maintain: `~/CLAUDE.md` (global, applies to every Claude Code session on this machine) and `<repo>/CLAUDE.md` (project-local, committed with the repo). Both get auto-injected into every session, which is why they need to stay lean and load-bearing.

**Why the HARD RULES are rules, not suggestions.** The top of `~/CLAUDE.md` has four numbered HARD RULES in caps-lock with "zero tolerance" language. That tone is deliberate. Each rule exists because I kept making the same specific mistake until I codified it. "Delegate implementation to agents" is there because I kept bloating my coordinator context with file reads. "Verify before you claim" is there because I kept forwarding unchecked assertions into PR bodies. The rules stop reading like rules the moment I soften them, so I do not soften them. The full walkthrough is in `appendix-claude-md.md`.

**Two-layer pattern: global vs. project.** Global rules are about how I drive Claude Code -- agent protocols, verification discipline, preference for ASCII. They travel with me to any repo. Project rules are about this particular codebase -- build commands, repo layout, conventions, what gets deployed where. Rule of thumb: if the guidance would survive cloning the repo to a new machine, put it project-local; if it would survive switching to a different repo, put it global. Concrete project-local content from `dotfiles/CLAUDE.md`: the `home-manager build --flake .#jon.gao@linux` invocation, the `nix/modules/` pointing at `configs/` as source of truth, the reminder that `.config/nvim` is a submodule. None of that is portable; all of it is essential inside this repo.

**Precedence.** When the rules collide, the order is: explicit user instruction in this turn > CLAUDE.md rules > skill instructions > default system behavior. The "Precedence" block at the top of `~/CLAUDE.md` makes this explicit so I can point to it when someone asks why Claude Code ignored a skill default. If a CLAUDE.md rule would block what I just asked for in-turn, Claude surfaces the conflict and asks rather than silently overriding either side.

**Evolution policy.** A rule earns its place by causing a painful failure mode at least twice. Preferences ("ASCII only", "batch independent tool calls", terse conversational register) accrete more loosely; I move them out when they stop pulling weight. Rules get retired when Claude Code changes the underlying tool surface enough that the rule is protecting a thing that no longer exists. The "Living with a moving target" mindset from section 14 applies inward: I do not pin rules to a specific protocol version.

**Memory is separate.** CLAUDE.md is policy; `claude-mem` auto-memory at `~/.claude/projects/*/memory/MEMORY.md` is history. Do not mix them. Rules are stable and I can recite them; memory is append-only and Claude reads it on my behalf. When I catch myself wanting to write a "remember this for next time" note into CLAUDE.md, that is a signal it belongs in memory instead.

See `appendix-claude-md.md` for the rules walkthrough and the rationale for the specific four HARD RULES.

---

## 9. Persistence: tmux + db-agents

Claude Code runs on a remote dev host (Arca) over SSH. SSH drops are routine; browser tabs crash; the laptop suspends. Persistence is what lets me tolerate all three without losing session state.

**The threat model.** An uninterrupted 4-hour coordinator session is fictional. In reality the network flakes three times, the laptop lid closes once, and the Arca host restarts for a security update sometime during the week. I need a persistence story for each of those layers or the loop stops partway through.

**Layer one: tmux for the interactive session.** My Linux zshrc auto-starts tmux on login. From `configs/zsh/zshrc.linux:8-11`:

```zsh
if [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
    command -v tmux >/dev/null && tmux -A
fi
```

`tmux -A` means "attach to the default session, creating it if it does not exist." The first SSH login creates session `default`; every subsequent login reattaches. The Claude Code CLI runs inside that session. When SSH drops, the CLI keeps running; when I reconnect, I am back where I left off with scrollback intact.

**Layer two: per-agent tmux-backed PTYs via db-agents.** `db-agents` spawns every teammate inside its own tmux session named `db-agent-*`. Each agent's turn-by-turn state lives in tmux buffer. When the `db-agents` daemon restarts (for example after the Arca host reboots), it rediscovers those sessions and re-binds its bookkeeping to maintain PTY proxy consistency. The agent does not restart; the proxy does.

**Port-forward reminder.** The dashboard serves `:13100` on Arca. On my laptop I either add `LocalForward 13100 localhost:13100` to `~/.ssh/config` for the Arca host, or run `arca et -t 13100` ad-hoc. The dashboard at `http://localhost:13100` shows each agent's state (IDLE / BUSY / INPUT) and lets me intervene without opening ten Claude Code panes.

**Recovery drill.** SSH drops mid-task: I reconnect, the shell runs `tmux -A`, I land back in the coordinator session. Dashboard tab crashes: refresh; the daemon re-serves from in-memory state. Arca reboots: db-agents restarts on boot, rediscovers the `db-agent-*` tmux sessions, re-binds. None of these recoveries require me to re-explain context to Claude Code.

**Where persistence stops helping.** The agent process itself dying. When an agent crashes mid-edit on a permission prompt, its tmux pane is gone; tmux has nothing to restore. Recovery then falls to the coordinator: finish the work directly, surgically remove the dead member from the team's `config.json` so `TeamDelete` can proceed, note the detour in the commit. Persistence saves you from a dead transport, not a dead process.

See `appendix-databricks-tools.md` for the db-agents install walkthrough and the port-forward details.

---

## 10. Coordinator + agent teams strategy

Section 5 and `appendix-agent-teams.md` cover the mechanics -- spawn, SendMessage, shutdown, inbox verification. This section is the question that comes earlier: given a task, do I spawn a full team, a single agent, or just do it myself?

**The three-way decision.**

*Coordinator direct.* One read or one bounded edit, no multi-step research, no permissions surface. The carve-outs are narrow: a single `Read` to answer a factual question, a single `grep` or `git status`, or the specific case where a delegated agent is blocked on a permission prompt mid-edit and the work is small enough that routing around the prompt costs more than doing the edit. That last case is earned by a concrete failure mode, not free license. When a recent `dotfiles-ascii-patcher` agent crashed awaiting a permission dialog, I applied the six em-dash replacements directly and recorded why in the commit (`ae5978c`). The next three tasks went back to full delegation.

*Single agent, no team.* Explore/Glob/Grep for a read-only lookup. HARD RULE 2 explicitly allows this one exception: a quick agent for a research question when no writes are coming. Anything that might produce an edit stays in a team even if only one agent runs, because I want the shutdown protocol and the inbox-file verification path.

*Full team with a lead.* The default. Any file edit, any multi-step research, any spawn that might beget a second spawn. Named team, named agents, explicit `shutdown_request` / `shutdown_response` handshake, `TeamDelete` at the end. Anything below this threshold is a judgment call I lean conservative on -- teams are cheap, uncoordinated spawns are expensive.

**Why the coordinator stays lightweight even for a one-agent team.** Context economy. Every token I spend reading a file is a token I cannot spend deciding what the next agent does. When I violate "coordinator stays lightweight" it is always gradual -- one harmless read leads to a second, and fifteen tool calls later I have forgotten which teammate is waiting on which handoff. That failure mode is exactly what HARD RULE 1 exists to defend against.

**Team shapes I have actually run.**

- *Sole-coder team.* One coder, several follow-up agents. Useful when the spec fits in one head but the follow-ups (build, test, commit, review) fan out.
- *Dual-worktree team.* Two coder agents, each in its own worktree, each in its own repo. A recent session had `plugin-coder` shipping a 21-commit branch in the plugin marketplace while `dotfiles-ascii-patcher` fixed six em-dashes in dotfiles so the plugin could vendor a source file verbatim. The coordinator used `SendMessage` to hand off when the upstream patch landed.
- *Investigator plus antagonist.* A debugging team where one agent proposes root causes and the other's only job is to try to falsify them. Covered in detail in section 11.1.

See `appendix-agent-teams.md` for the protocol details (spawn, SendMessage, shutdown, inbox verification).

---

## 11. Parallelization playbook

Four named patterns. Each one I have run at least once; each one names when to use it, the shape of the team, and a concrete example. I reach for these in this order when a task looks parallelizable.

### 11.1 Antagonist investigation

*When.* Root-cause debugging with two or more plausible hypotheses. The failure mode of a single investigator agent is confirmation bias: it latches onto the first hypothesis that fits the symptom and stops looking for counter-evidence.

*Shape.* Two agents, both read-only. The **investigator** emits candidate hypotheses with proposed verification commands and expected observations. The **antagonist** gets a single-line mandate: "for each hypothesis, either produce evidence that rules it out, or flag insufficient data." Both run in parallel under `isolation: "worktree"` when code-reading is involved. The coordinator only accepts the hypothesis that survives the antagonist pass.

*Example.* SC-227980 presented three candidate causes for a spike in the probe dashboard: probe over-emission, pod restart artifacts, and Prometheus counter resets. Each was refuted by specific evidence -- probe rates were flat across the window, the pod uptime graph was continuous, Prometheus counters showed monotonic growth -- before the real cause, an M3 query-layer phantom read, was accepted. Running antagonist-first meant I committed no code to the wrong fix.

*Why it works.* Bias is suppressed by making the skeptic role an explicit agent with a refutation-only brief. Three minutes of "refute this" routinely saves three hours of chasing the wrong trace.

### 11.2 Build / test / commit-push / review fan-out

*When.* A coder agent has just finished an implementation. The follow-up activities -- build verification, test run, commit-and-push, PR self-review -- have no mutual dependencies.

*Shape.* Four parallel agents spawned in a single coordinator message:

- `build-validator` runs the build command and captures output.
- `test-runner` runs tests and captures output.
- `commit-and-push-er` uses `commit-commands:commit-push-pr`.
- `reviewer` uses `pr-review-toolkit:review-pr`.

Each uses `isolation: "worktree"` if doing writes; read-only ones share the checkout. The coordinator waits for SendMessage notifications rather than polling teammates in-band.

*Example.* The recent `claude-workflow-bootstrap` plugin PR -- 21 commits, sibling dotfiles patch, full test matrix, marketplace registration, plugin self-review -- ran that tail sequentially inside one agent. The next plugin I ship will fan this out. Wall-clock savings are real because build and test are each several minutes and they share no state with commit ordering or review.

*Why it works.* Build is orthogonal to commit ordering. Tests are orthogonal to review. Running them serially is pure wall-clock waste.

### 11.3 Specialization via narrow scope

*When.* Any task big enough that a generalist agent would swing across unrelated domains. Cross-repo work is the cleanest case.

*Shape.* One agent per concern, each with a scoped skill set. An agent's permission surface should be exactly the tools and paths it needs and nothing else.

*Example.* The bootstrap-plugin session ran `plugin-coder` (`superpowers:subagent-driven-development` + `commit-commands` + `plugin-builder:plugin-self-review`) inside the plugin-marketplace worktree, while `dotfiles-ascii-patcher` (`dotfiles-editor` + `commit-commands`) ran inside dotfiles fixing upstream em-dashes. Neither agent could touch the other's repo; neither needed to. When one got stuck on a permission prompt, replacement was cheap because the scope was already small.

*Why it works.* Narrow scope shrinks the permission surface (fewer prompts to block on), keeps each agent's context window small, and makes replacement cheap when one crashes. The upstream-first fix pattern -- fix the source rather than paper over the downstream -- composes naturally with this: one specialized agent patches upstream while another proceeds on disjoint downstream work.

### 11.4 Skills and plugins as the composition API

*When.* Whenever the right skill exists for a subtask, the coordinator's job is to pick the skill for the role, not to hand-roll the work.

*Shape.* Each spawned agent receives a named skill or plugin as its primary tool. The coordinator composes; the skill executes. Picking the right skill per role is the highest-leverage thing the coordinator does.

*Example.* The bootstrap-plugin session composed `superpowers:subagent-driven-development` (execution discipline), `plugin-builder:plugin-self-review` (marketplace compliance validation), and `commit-commands:commit` (commit-message format). I did not re-derive any of the three. Somebody else maintains each; the composition was almost free.

*Why it works.* Skills encode other people's lessons. Every token I spend picking a skill for a role is higher-leverage than a token spent reinventing commit-message formatting or plugin-review heuristics. The coordinator's taste -- which skills match which roles -- is the part I keep sharpening; the skill internals are not my problem.

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
