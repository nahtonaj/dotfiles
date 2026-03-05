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
  home.file.".claude/agents" = {
    source = "${flakePath}/.claude/agents";
    recursive = true;
  };

  # --- Helpers (node needed for claude-flow) ---
  home.packages = with pkgs; [
    nodejs_22
  ];
}
