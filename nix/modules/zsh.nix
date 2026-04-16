{ config, pkgs, lib, flakePath, ... }:

let
  zsh-vi-mode = pkgs.fetchFromGitHub {
    owner = "jeffreytse";
    repo = "zsh-vi-mode";
    rev = "v0.11.0";
    sha256 = "sha256-xbchXJTFWeABTwq6h4KWLh+EvydDrDzcY9AQVK65RS8=";
  };
  zsh-fzf-history-search = pkgs.fetchFromGitHub {
    owner = "joshskidmore";
    repo = "zsh-fzf-history-search";
    rev = "d5a9730b5b4cb0b39959f7f1044f9c52e65a2571";
    sha256 = "sha256-o8IQszQ4/PLX1FlUvJpowR2Tev59N8lI20VymZ+Hp4w=";
  };
  zsh-autocomplete = pkgs.fetchFromGitHub {
    owner = "marlonrichert";
    repo = "zsh-autocomplete";
    rev = "24.09.04";
    sha256 = "sha256-o8IQszQ4/PLX1FlUvJpowR2Tev59N8lI20VymZ+Hp4w=";
  };
in
{
  # Disable programs.zsh so it does not claim ~/.zshrc.
  # Plugins are installed manually below; everything else lives in the mutable zshrc.
  programs.zsh.enable = false;

  home.file.".zsh/plugins/zsh-vi-mode".source = zsh-vi-mode;
  home.file.".zsh/plugins/zsh-fzf-history-search".source = zsh-fzf-history-search;
  home.file.".zsh/plugins/zsh-autocomplete".source = zsh-autocomplete;

  home.file.".zshrc".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/configs/zsh/zshrc";
}
