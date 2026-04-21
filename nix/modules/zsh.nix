{ config, pkgs, lib, flakePath, ... }:

let
  themeFile = builtins.readFile "${flakePath}/configs/zsh/databricks.zsh-theme";
in
{
  # Bidirectional symlinks for zsh-related dotfiles
  home.file.".aliasrc" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/configs/aliasrc";
    force = true;
  };
  home.file.".oh-my-zsh" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.oh-my-zsh";
    force = true;
  };

  programs.zsh = {
    enable = true;
    autosuggestion = {
      enable = true;
      highlight = "fg=28";
    };
    # Syntax highlighting sourced manually in initContent after registering
    # autocomplete widget stubs to avoid "unhandled ZLE widget" warnings.
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
      # zsh-autocomplete removed: it duplicated compinit and added ~1s of
      # startup. zsh-autosuggestions + fzf history search cover its
      # day-to-day features.
    ];

    # Cache compinit. Security audit (compaudit) is skipped when the dump is
    # newer than 24h; otherwise rebuild and recompile for the next shell.
    completionInit = ''
      autoload -Uz compinit
      if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
        compinit -C
      else
        compinit
        { [[ -f ~/.zcompdump ]] && zcompile -M ~/.zcompdump ~/.zcompdump } &!
      fi
    '';

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
      # Nix rebuild
      nrs = "sudo nix run --extra-experimental-features 'nix-command flakes' nix-darwin -- switch --flake ~/dotfiles#jon-gao-mac";
    };

    sessionVariables = {
      EDITOR = "nvim";
      SDKMAN_DIR = "$HOME/.sdkman";
      NVM_DIR = "$HOME/.nvm";
    };

    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Nix profile (ensures nix/home-manager available in all shells)
        if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
          . "$HOME/.nix-profile/etc/profile.d/nix.sh"
        fi

        # PATH setup
        export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH
        export PATH=$HOME/bin:/usr/local/bin:$PATH
        export PATH=$HOME/.local/share/coursier/bin:$PATH
        export PATH=$HOME/.local/bin:$PATH
        export PATH="$HOME/Library/Application Support/waveterm/bin:$PATH"

        # Java configuration for Metals
        export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
        export PATH=$JAVA_HOME/bin:$PATH
      '')

      ''
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

        # Load colors for prompt
        autoload -U colors && colors

        # Enable prompt substitution (needed for $(git branch ...) in PROMPT)
        setopt PROMPT_SUBST

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

        # Custom functions
        set-title() {
            echo -e "\e]0;$*\007"
        }

        # Resilient port-forwarding tunnel to arca.ssh. Detects prior
        # autossh/ssh holding the same ports and asks before killing them,
        # so re-running doesn't silently wipe state or fail with
        # "Could not request local forwarding".
        arcatunnel() {
            local ports=(13100 13101 37777)
            local to_kill=()
            local stale_autossh
            stale_autossh=$(pgrep -f "autossh.*arca\.ssh" 2>/dev/null)
            if [ -n "$stale_autossh" ]; then
                to_kill+=(''${=stale_autossh})
            fi
            for p in "''${ports[@]}"; do
                local pids
                pids=$(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null)
                if [ -n "$pids" ]; then
                    to_kill+=(''${=pids})
                fi
            done
            # Dedupe.
            to_kill=(''${(u)to_kill})
            if [ ''${#to_kill[@]} -gt 0 ]; then
                echo "Conflicting processes on arca tunnel ports:" >&2
                ps -o pid,comm,args -p ''${to_kill[@]} 2>/dev/null | sed 's/^/  /' >&2
                if read -q "?Kill them and continue? [y/N] "; then
                    echo
                    kill ''${to_kill[@]} 2>/dev/null
                    sleep 0.5
                else
                    echo
                    echo "arcatunnel aborted." >&2
                    return 1
                fi
            fi
            AUTOSSH_POLL=30 AUTOSSH_GATETIME=0 autossh -M 0 -N \
                -o ServerAliveInterval=30 \
                -o ServerAliveCountMax=3 \
                -o ExitOnForwardFailure=yes \
                -L 13100:localhost:13100 \
                -L 13101:localhost:13101 \
                -L 37777:localhost:37777 \
                -R 27124:localhost:27124 \
                arca.ssh
        }

        # Start Arca, then open the tunnels. Thin wrapper around arcatunnel.
        aa() {
            arca start "$@" || return
            arcatunnel
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

        # SDKMAN — lazy load on first `sdk` invocation.
        if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
            sdk() {
                unset -f sdk
                source "$HOME/.sdkman/bin/sdkman-init.sh"
                sdk "$@"
            }
        fi

        # NVM — lazy load on first invocation of nvm / node / npm / npx /
        # yarn / pnpm. Saves ~30ms on most shells plus whatever the first
        # `nvm.sh` parse actually costs in the cold case.
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            _nvm_lazy_load() {
                unset -f nvm node npm npx yarn pnpm _nvm_lazy_load 2>/dev/null
                source "$NVM_DIR/nvm.sh"
                [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
            }
            for _cmd in nvm node npm npx yarn pnpm; do
                eval "$_cmd() { _nvm_lazy_load; $_cmd \"\$@\"; }"
            done
            unset _cmd
        fi

      ''
    ];
  };
}
