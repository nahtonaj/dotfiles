{ config, pkgs, flakePath, ... }:

{
  home.file."bin/tmux-osc52-copy" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/bin/tmux-osc52-copy";
  };

  home.file."bin/tmux-fzf-url-copy" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/bin/tmux-fzf-url-copy";
  };

  home.file."bin/tmux-fix-resurrect" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/bin/tmux-fix-resurrect";
  };

  home.file."bin/tmux-validate-save" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/bin/tmux-validate-save";
  };
}
