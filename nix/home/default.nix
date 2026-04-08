{ config, pkgs, flakePath, ... }:

{
  imports = [
    ../modules/zsh.nix
    ../modules/tmux.nix
    ../modules/nvim.nix
    ../modules/git.nix
    ../modules/fzf.nix
    ../modules/zoxide.nix
    ../modules/yazi.nix
    ../modules/lazygit.nix
    ../modules/zellij.nix
    ../modules/scripts.nix
    ../modules/databricks.nix
    ../modules/ideavim.nix
    ../modules/tridactyl.nix
    ../modules/ssh.nix
    ../modules/claude.nix
    ../modules/arche.nix
  ];

  home.username = "jon.gao";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    htop
    tree
    curl
    wget
  ];
}
