#!/usr/bin/env zsh
set +xe

PWD=$(pwd)

# link over .zshrc and move existing to backup
function move_backup_link_existing_file() {
if [ -f "$1" ]; then
  mv "$1" "${2}_backup"
fi
ln -s "$2" "$(dirname "${1}")"}

# helper function for existing directory, and merging and linking
function move_merge_link_existing_directory() {
  PATH_TO_EXISTING=$1
  LINKED_DIR=$2
  # check if the .config directory already exists
  if [ -d "$PATH_TO_EXISTING" ]; then
    echo "Found existing $PATH_TO_EXISTING directory, will merge everything into our directory"
    echo "We will then remove the existing directory and link this one"
    mv "${PATH_TO_EXISTING}/*" "${LINKED_DIR}" && rm -rf "${PATH_TO_EXISTING}" "${PATH_TO_EXISTING}_backup" && ln -s "${LINKED_DIR}" "$(dirname "${PATH_TO_EXISTING}")"
  fi
}

# helper function for existing directory, and creating backup and linking
function move_backup_link_existing_directory() {
  PATH_TO_EXISTING=$1
  LINKED_DIR=$2
  # check if the .config directory already exists
  if [ -d "$PATH_TO_EXISTING" ]; then
    echo "Found existing $PATH_TO_EXISTING directory, will merge everything into our directory"
    echo "We will then remove the existing directory and link this one"
    mv "${PATH_TO_EXISTING}/*" "${LINKED_DIR}" && mv "${PATH_TO_EXISTING}" "${PATH_TO_EXISTING}_backup" && ln -s "${LINKED_DIR}" "$(dirname "${PATH_TO_EXISTING}")"
  fi
}

move_merge_link_existing_directory "${HOME}/.config/" "$PWD/.config/"
move_backup_link_existing_directory "${HOME}/.oh-my-zsh/" "$PWD/.oh-my-zsh/"

move_backup_link_existing_file "${HOME}/.zshrc" "$PWD/.zshrc"
move_backup_link_existing_file "${HOME}/.tmux.conf" "$PWD/.tmux.conf"





