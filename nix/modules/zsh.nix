{ config, pkgs, lib, flakePath, ... }:

let
  themeFile = builtins.readFile "${flakePath}/configs/zsh/databricks.zsh-theme";
in
{
  programs.zsh = {
    enable = true;
    autosuggestion = {
      enable = true;
      highlight = "fg=28";
    };
    syntaxHighlighting.enable = true;

    # NOTE: On first build, nix will error with "hash mismatch" and print the
    # correct sha256. Replace lib.fakeHash with the value from the error output.
    plugins = [
      {
        name = "zsh-vi-mode";
        src = pkgs.fetchFromGitHub {
          owner = "jeffreytse";
          repo = "zsh-vi-mode";
          rev = "v0.11.0";
          sha256 = lib.fakeHash;
        };
      }
      {
        name = "zsh-fzf-history-search";
        src = pkgs.fetchFromGitHub {
          owner = "joshskidmore";
          repo = "zsh-fzf-history-search";
          rev = "d5a9730b5b4cb0b39959f7f1044f9c52e65a2571";
          sha256 = lib.fakeHash;
        };
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.fetchFromGitHub {
          owner = "marlonrichert";
          repo = "zsh-autocomplete";
          rev = "24.09.04";
          sha256 = lib.fakeHash;
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

    initExtraFirst = ''
      # PATH setup
      export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH
      export PATH=$HOME/bin:/usr/local/bin:$PATH
      export PATH=$HOME/.local/share/coursier/bin:$PATH
      export PATH=$HOME/.local/bin:$PATH

      # Java configuration for Metals
      export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
      export PATH=$JAVA_HOME/bin:$PATH
    '';

    initExtra = ''
      # Load colors for prompt
      autoload -U colors && colors

      # Prompt (from databricks.zsh-theme)
      ${themeFile}

      # Completion style
      COMPLETION_WAITING_DOTS="true"

      # Vi-mode arrow key fix
      () {
        while (( ARGC )); do
          bindkey -M $1 '^[OA' up-line-or-history
          bindkey -M $1 '^[[A' up-line-or-history
          bindkey -M $1 '^[OB' down-line-or-history
          bindkey -M $1 '^[[B' down-line-or-history
          shift
        done
      } emacs viins vicmd

      # Autocomplete settings
      zstyle ':autocomplete:*' widget-style menu-select
      bindkey -M menuselect '\r' accept-line
      zstyle ':autocomplete:*' list-lines 7

      # Custom functions
      set-title() {
          echo -e "\e]0;$*\007"
      }

      ssh() {
          set-title $*;
          /usr/bin/ssh -2 $*;
          set-title $HOST;
      }

      separator() {
          if [[ -z $COLUMNS ]]; then
              COLUMNS=$(tput cols)
          fi
          lengthOfTitle=$((''${#1}+2))
          numberOfCharacters=$(( ($COLUMNS - $lengthOfTitle)/2 ))
          printf "=%.0s"  $(seq 1 ''${numberOfCharacters}); printf " ''${1} "; printf "=%.0s"  $(seq 1 ''${numberOfCharacters}); printf "\n"
      }

      mkcd () {
        case "$1" in
          */..|*/../) cd -- "$1";;
          /*/../*) (cd "''${1%/../*}/.." && mkdir -p "./''${1##*/../}") && cd -- "$1";;
          /*) mkdir -p "$1" && cd "$1";;
          */../*) (cd "./''${1%/../*}/.." && mkdir -p "./''${1##*/../}") && cd "./$1";;
          ../*) (cd .. && mkdir -p "''${1#.}") && cd "$1";;
          *) mkdir -p "./$1" && cd "./$1";;
        esac
      }

      # Yazi helper for changing current working directory
      function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }

      # Kiro integration (conditional)
      [[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

      # SDKMAN (conditional)
      [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

      # NVM (conditional)
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

      # Auto-start tmux and restore session
      if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
        exec tmux new-session -A -s main
      fi
    '';
  };
}
