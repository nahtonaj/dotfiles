{ config, pkgs, ... }:

{
  programs.git.enable = true;

  # Personal identity for dotfiles repo
  programs.git.includes = [
    {
      condition = "gitdir:~/dotfiles/";
      contents = {
        user.email = "jonathan-gao@hotmail.com";
      };
    }
  ];

  # Global gitignore
  xdg.configFile."git/ignore".text = ''
    **/.claude/settings.local.json
  '';
}
