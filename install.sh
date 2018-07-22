#!/usr/bin/env bash

set -e
set -u

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks/*; do
  [ -r "${file}" ] && [ -e "${file}" ] && rm -f ${HOME}/.`basename ${file}` && ln -s ${file} ${HOME}/.`basename ${file}`
done

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/init/*; do
  [ -r "${file}" ] && [ -e "${file}" ] && "${file}"
done

if [ `uname` == 'Darwin' ]; then
  brew cleanup
else
  sudo apt-get autoremove -y
  sudo apt-get clean all
fi
