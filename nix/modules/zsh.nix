{ config, pkgs, lib, flakePath, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion = {
      enable = true;
      highlight = "fg=28";
    };
    syntaxHighlighting.enable = false;

    plugins = [
      {
        name = "zsh-vi-mode";
        src = pkgs.fetchFromGitHub {
          owner = "jeffreytse";
          repo = "zsh-vi-mode";
          rev = "v0.11.0";
          sha256 = "sha256-xbchXJTFWeABTwq6h4KWLh+EvydDrDzcY9AQVK65RS8=";
        };
      }
      {
        name = "zsh-fzf-history-search";
        src = pkgs.fetchFromGitHub {
          owner = "joshskidmore";
          repo = "zsh-fzf-history-search";
          rev = "d5a9730b5b4cb0b39959f7f1044f9c52e65a2571";
          sha256 = "sha256-o8IQszQ4/PLX1FlUvJpowR2Tev59N8lI20VymZ+Hp4w=";
        };
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.fetchFromGitHub {
          owner = "marlonrichert";
          repo = "zsh-autocomplete";
          rev = "24.09.04";
          sha256 = "sha256-o8IQszQ4/PLX1FlUvJpowR2Tev59N8lI20VymZ+Hp4w=";
        };
      }
    ];

    shellAliases = {
      ll = "ls -al";
      jp = "jupyter-lab --no-browser";
      lg = "lazygit";
      vim = "nvim";
      # Cherry-picked git aliases (replaces oh-my-zsh git plugin)
      ga = "git add";
      gaa = "git add --all";
      gb = "git branch";
      gc = "git commit";
      gcam = "git commit --all --message";
      gcmsg = "git commit --message";
      gco = "git checkout";
      gd = "git diff";
      gds = "git diff --staged";
      gf = "git fetch";
      gl = "git pull";
      glog = "git log --oneline --decorate --graph";
      gp = "git push";
      gpf = "git push --force-with-lease";
      grb = "git rebase";
      grbi = "git rebase --interactive";
      gst = "git status";
      gsw = "git switch";
      gswc = "git switch --create";
    };

    sessionVariables = {
      EDITOR = "nvim";
      SDKMAN_DIR = "$HOME/.sdkman";
      NVM_DIR = "$HOME/.nvm";
    };
  };

  # mkOutOfStoreSymlink needs the real filesystem path, not nix store path from self
  home.file.".zshrc".source = lib.mkForce
    (config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/configs/zsh/zshrc");
}
