#!/usr/bin/env bash

set -e
set -u

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks/*; do
  [ -r "${file}" ] && [ -e "${file}" ] && rm -f ${HOME}/.`basename ${file}` && ln -s ${file} ${HOME}/.`basename ${file}`
done

source "${HOME}/.bashrc"

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/install/*; do
  [ -r "${file}" ] && [ -x "${file}" ] && "${file}"
done

if [ `uname` == 'Darwin' ]; then
  brew cleanup
elif command -v apt-get > /dev/null 2>&1; then
  sudo apt-get autoremove -y
  sudo apt-get clean all
fi

if command -v subl > /dev/null 2>&1; then
  cd sublime && ./install.sh
fi
