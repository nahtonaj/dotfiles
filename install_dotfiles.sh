#!/usr/bin/env zsh
set +xe

PWD=$(pwd)

# link over .zshrc and move existing to backup
if [ -f "${HOME}/.zshrc" ]; then
  mv "${HOME}/.zshrc" "${HOME}/.zshrc_backup"
fi
ln -s "$PWD/.zshrc" "${HOME}"

# check if the .config directory already exists
if [ -d "${HOME}/.config" ]; then
  echo "Found existing .config directory, will merge everything into our .config directory"
  echo "We will then remove the existing directory and link this one"
  mv ${HOME}/config/* "$PWD/.config" && rm -rf ${HOME}/.config && ln -s "$PWD/.config" ${HOME}
fi





