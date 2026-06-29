# ~/.config/fish/conf.d/z_dotfiles.fish
# Main dotfiles configuration for Fish shell

# ─── Environment & Editor ──────────────────────────────────────────────────
set -gx EDITOR nvim

# ─── Path Setup ────────────────────────────────────────────────────────────
fish_add_path -g ~/bin /usr/local/bin /home/linuxbrew/.linuxbrew/bin ~/.local/bin ~/.local/share/coursier/bin

# Linux: JAVA_HOME for Metals (no-op if absent)
if test -d /usr/lib/jvm/java-17-openjdk-amd64
    set -gx JAVA_HOME /usr/lib/jvm/java-17-openjdk-amd64
    fish_add_path -g $JAVA_HOME/bin
end

# ─── Core Utilities (Zoxide & Fzf) ─────────────────────────────────────────
if command -v zoxide >/dev/null
    zoxide init fish | source
end
if command -v fzf >/dev/null
    fzf --fish | source
end

# ─── Standard Aliases ──────────────────────────────────────────────────────
alias lg='lazygit'
alias vim='nvim'

# ─── Git Aliases ───────────────────────────────────────────────────────────
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gc='git commit'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias gco='git checkout'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git pull'
alias glog='git log --oneline --decorate --graph'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias grb='git rebase'
alias grbi='git rebase --interactive'
alias gst='git status'
alias gsw='git switch'
alias gswc='git switch --create'

# ─── Custom Helper Functions ────────────────────────────────────────────────

# Yazi helper to cd to Yazi's exit directory
function y
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file=$tmp
    if test -s $tmp
        set -l cwd (cat $tmp)
        if test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end
    end
    rm -f -- $tmp
end

# Make directory and cd into it
function mkcd
    mkdir -p $argv[1]
    and cd $argv[1]
end

# Current date in Pacific time
function today
    date -I -d "-8 hours"
end
