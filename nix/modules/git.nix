{ config, pkgs, ... }:

{
  programs.git.enable = true;

  # Global gitignore
  xdg.configFile."git/ignore".text = ''
    **/.claude/settings.local.json
  '';
}
