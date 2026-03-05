{ config, pkgs, flakePath, ... }:

{
  # Custom Claude agents — symlinked from dotfiles repo
  home.file.".claude/agents/custom/nix-specialist.md" = {
    source = "${flakePath}/claude-agents/custom/nix-specialist.md";
  };

  home.file.".claude/agents/custom/test-long-runner.md" = {
    source = "${flakePath}/claude-agents/custom/test-long-runner.md";
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

  home.file.".claude/agents/custom/ddd-domain-expert.md" = {
    source = "${flakePath}/claude-agents/custom/ddd-domain-expert.md";
  };

  home.file.".claude/agents/meta/agent-definer.md" = {
    source = "${flakePath}/claude-agents/meta/agent-definer.md";
  };

  # Ensure node/npm available for claude-flow
  home.packages = with pkgs; [
    nodejs_22
  ];
}
