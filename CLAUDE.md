# Dotfiles Repo — Project Instructions

## Repository Structure

```
flake.nix, flake.lock     — Nix flake entry point
nix/home/                  — Home Manager profiles (default, linux, darwin)
nix/modules/               — Shared Nix modules (zsh, tmux, git, yazi, etc.)
nix/modules-darwin/        — macOS-only modules (aerospace, sketchybar, karabiner)
nix/hosts/                 — Host-specific config (darwin)
configs/                   — Config source files referenced by Nix modules
.claude/agents/            — Claude agent definitions (deployed recursively via claude.nix)
.claude/skills/            — Claude skill definitions (deployed recursively via claude.nix)
.claude/commands/          — Claude commands (deployed recursively via claude.nix)
bin/                       — Helper scripts (tmux-osc52-copy, tmux-fzf-url-copy)
.config/                   — Active configs (sketchybar, karabiner, aerospace, yazi, skhd, yabai, nvim submodule)
```

## Build & Validation

```bash
# Build (dry-run, safe)
home-manager build --flake .#jon.gao@linux

# Deploy
home-manager switch --flake .#jon.gao@linux

# macOS
darwin-rebuild switch --flake .#jon.gao-mac

# Debug
home-manager build --flake .#jon.gao@linux --show-trace 2>&1 | head -100
```

- ALWAYS validate with `home-manager build` after Nix changes
- ALWAYS read a file before editing it

## Nix Module Pattern

New config modules follow this pattern:
1. Source file in `configs/<tool>/`
2. Nix module in `nix/modules/<tool>.nix` using `home.file` or `programs.<tool>`
3. Import in `nix/home/default.nix`

Example from `nix/modules/claude.nix`:
```nix
home.file.".claude/agents" = {
  source = "${flakePath}/.claude/agents";
  recursive = true;
};
```

## What Gets Deployed via Nix

- Shell config (zsh, aliases, env vars)
- Terminal tools (tmux, fzf, zoxide, lazygit, yazi, zellij)
- Editor config (nvim submodule, ideavim, tridactyl)
- Git config and SSH config
- Claude agents and CLAUDE.md (via `configs/claude/`)
- Scripts in `bin/`

## Conventions

- Config source files live in `configs/`, NOT directly in the repo root
- macOS-only modules go in `nix/modules-darwin/`
- `flakePath` refers to the repo root in Nix expressions
- The `.config/nvim` directory is a git submodule — don't edit it directly here
