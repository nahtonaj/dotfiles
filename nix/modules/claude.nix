{ config, pkgs, flakePath, ... }:

{
  home.file."CLAUDE.md" = {
    source = "${flakePath}/configs/claude/CLAUDE.md";
  };

  # Out-of-store symlink so Claude Code can write back to the repo file
  home.file.".claude/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/claude/settings.json";
  };
}
