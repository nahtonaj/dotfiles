{ config, pkgs, lib, flakePath, ... }:

# Minimal zsh glue: home-manager's programs.zsh is disabled so the entire
# interactive shell is driven by the hand-rolled configs/zsh/zshrc. Nix
# installs the `antidote` plugin manager, whose static bundle is built on
# first run (and whenever configs/zsh/zsh_plugins.txt changes).
#
# See configs/zsh/zshrc for the full startup pipeline.

{
  home.packages = [ pkgs.antidote ];

  # antidote's share/ doesn't get collected into the user profile by
  # home-manager, so expose it at a stable path that zshrc can source.
  home.file.".config/antidote".source = "${pkgs.antidote}/share/antidote";

  home.file.".zshrc" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/configs/zsh/zshrc";
    force = true;
  };

  # Kept as-is for apps that may still reference these paths.
  home.file.".aliasrc" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/aliasrc";
    force = true;
  };
  home.file.".oh-my-zsh" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.oh-my-zsh";
    force = true;
  };

  programs.zsh.enable = false;
}
