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

Last verified against: Claude Code 2.1.116, claude-mem unavailable, db-agents v1.6.1 (2026-04-21).
