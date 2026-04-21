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

Last verified against: Claude Code 2.1.116, claude-mem unavailable, db-agents v1.6.1 (2026-04-21).
