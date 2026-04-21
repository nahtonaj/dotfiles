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

Last verified against: Claude Code 2.1.116, claude-mem unavailable, db-agents v1.6.1 (2026-04-21).
