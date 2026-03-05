{ config, pkgs, flakePath, ... }:

{
  home.file."CLAUDE.md" = {
    source = "${flakePath}/configs/claude/CLAUDE.md";
  };
}
