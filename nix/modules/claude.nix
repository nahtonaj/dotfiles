{ config, pkgs, flakePath, ... }:

{
  # --- Core config ---
  home.file."CLAUDE.md" = {
    source = "${flakePath}/configs/claude/CLAUDE.md";
  };

  home.file.".claude/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/claude/settings.json";
  };

  # --- Commands & skills ---
  home.file.".claude/commands" = {
    source = "${flakePath}/.claude/commands";
    recursive = true;
  };

  home.file.".claude/skills" = {
    source = "${flakePath}/.claude/skills";
    recursive = true;
  };

  # --- Agents ---
  home.file.".claude/agents/custom/nix-specialist.md" = {
    source = "${flakePath}/claude-agents/custom/nix-specialist.md";
  };

  home.file.".claude/agents/custom/test-long-runner.md" = {
    source = "${flakePath}/claude-agents/custom/test-long-runner.md";
  };

  home.file.".claude/agents/custom/ddd-domain-expert.md" = {
    source = "${flakePath}/claude-agents/custom/ddd-domain-expert.md";
  };

  home.file.".claude/agents/devops/databricks-job-runner.md" = {
    source = "${flakePath}/claude-agents/devops/databricks-job-runner.md";
  };

  home.file.".claude/agents/dotfiles/dotfiles-doctor.md" = {
    source = "${flakePath}/claude-agents/dotfiles/dotfiles-doctor.md";
  };

  home.file.".claude/agents/dotfiles/dotfiles-editor.md" = {
    source = "${flakePath}/claude-agents/dotfiles/dotfiles-editor.md";
  };

  home.file.".claude/agents/dotfiles/dotfiles-onboarder.md" = {
    source = "${flakePath}/claude-agents/dotfiles/dotfiles-onboarder.md";
  };

  home.file.".claude/agents/dotfiles/dotfiles-porter.md" = {
    source = "${flakePath}/claude-agents/dotfiles/dotfiles-porter.md";
  };

  home.file.".claude/agents/meta/agent-definer.md" = {
    source = "${flakePath}/claude-agents/meta/agent-definer.md";
  };

  # --- Helpers (node needed for claude-flow) ---
  home.packages = with pkgs; [
    nodejs_22
  ];
}
