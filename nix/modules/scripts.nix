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
}
