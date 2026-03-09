{ config, pkgs, flakePath, ... }:

{
  home.file."bin/tmux-osc52-copy" = {
    source = "${flakePath}/bin/tmux-osc52-copy";
    executable = true;
  };

  home.file."bin/tmux-fzf-url-copy" = {
    source = "${flakePath}/bin/tmux-fzf-url-copy";
    executable = true;
  };

  home.file."bin/tmux-fix-resurrect" = {
    source = "${flakePath}/bin/tmux-fix-resurrect";
    executable = true;
  };

  home.file."bin/tmux-validate-save" = {
    source = "${flakePath}/bin/tmux-validate-save";
    executable = true;
  };
}
