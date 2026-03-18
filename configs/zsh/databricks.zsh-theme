# Databricks ZSH prompt theme (standalone, no oh-my-zsh dependency)
# Requires: autoload -U colors && colors

local git_branch='$(git branch --show-current 2> /dev/null)'

# Prompt format:
#
# PRIVILEGES USER at MACHINE in DIRECTORY on git:BRANCH [TIME]
# $ COMMAND
PROMPT="%{$terminfo[bold]$fg[blue]%}#%{$reset_color%} \
%(#,%{$fg[red]%}%n%{$reset_color%},%{$fg[cyan]%}%n) \
%{$fg[white]%}at \
%{$fg[green]%}%m \
%{$fg[white]%}in \
%{$terminfo[bold]$fg[yellow]%}%~%{$reset_color%}\
 (git:${git_branch})\
 \
%{$fg[white]%}[%*]
%{$terminfo[bold]$fg[red]%}%(#,%#,$) %{$reset_color%}"
