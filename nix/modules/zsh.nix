{ config, pkgs, lib, flakePath, ... }:

{
  # Disable programs.zsh so it does not claim ~/.zshrc.
  # Plugins are managed by antidote (see configs/zsh/zsh_plugins.txt);
  # everything else lives in the mutable zshrc.
  programs.zsh.enable = false;

  # antidote provides share/antidote/antidote.zsh in ~/.nix-profile/share/
  home.packages = [ pkgs.antidote ];

  home.file.".zshrc".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/configs/zsh/zshrc";
}
