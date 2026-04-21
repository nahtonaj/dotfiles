{ config, pkgs, flakePath, ... }:

{
  home.activation.createScriptSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/bin"
    ln -sfn "${config.home.homeDirectory}/dotfiles/bin/tmux-osc52-copy" "$HOME/bin/tmux-osc52-copy"
    ln -sfn "${config.home.homeDirectory}/dotfiles/bin/tmux-fzf-url-copy" "$HOME/bin/tmux-fzf-url-copy"
    ln -sfn "${config.home.homeDirectory}/dotfiles/bin/tmux-fix-resurrect" "$HOME/bin/tmux-fix-resurrect"
    ln -sfn "${config.home.homeDirectory}/dotfiles/bin/tmux-validate-save" "$HOME/bin/tmux-validate-save"
  '';
}
