{ config, pkgs, ... }:

{
  programs.zoxide = {
    enable = true;
    # zsh integration handled manually in zsh.nix via a build-time-cached
    # init script so we avoid forking `zoxide init zsh` per shell start.
    enableZshIntegration = false;
  };
}
