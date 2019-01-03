#!/usr/bin/env bash

set -e
set -u

for file in "${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks"/*; do
  basenameFile=$(basename "${file}")
  [ -r "${file}" ] && [ -e "${file}" ] && rm -f "${HOME}/.${basenameFile}" && ln -s "${file}" "${HOME}/.${basenameFile}"
done

set +u
source "${HOME}/.bashrc"
set -u

for file in "${HOME}/code/src/github.com/ViBiOh/dotfiles/install"/*; do
  [ -r "${file}" ] && [ -x "${file}" ] && "${file}"
done

if [[ "${IS_MACOS}" == true ]]; then
  brew cleanup
elif command -v apt-get > /dev/null 2>&1; then
  sudo apt-get autoremove -y
  sudo apt-get clean all
fi

if command -v subl > /dev/null 2>&1; then
  cd sublime && ./install.sh
fi
