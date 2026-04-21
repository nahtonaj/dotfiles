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

Last verified against: Claude Code 2.1.116, claude-mem unavailable, db-agents v1.6.1 (2026-04-21).
