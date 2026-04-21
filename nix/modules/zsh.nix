{ config, pkgs, lib, flakePath, ... }:

# Minimal zsh glue: home-manager's programs.zsh is disabled so the entire
# interactive shell is driven by the hand-rolled configs/zsh/zshrc
# (symlinked below). Nix installs the `antidote` plugin manager; the static
# bundle is built on first run and whenever zsh_plugins.txt changes.
{
  programs.zsh.enable = false;

  home.packages = [ pkgs.antidote ];

  # On nix-darwin, `/share/antidote/` is not in pathsToLink so the package's
  # files never reach ~/.nix-profile/share/. Expose them at a stable path
  # that zshrc can source. Harmless on linux where the profile linker
  # already surfaces share/antidote/.
  home.file.".config/antidote".source = "${pkgs.antidote}/share/antidote";

  home.file.".zshrc".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/configs/zsh/zshrc";
}
