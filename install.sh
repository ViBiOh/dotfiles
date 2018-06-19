#!/usr/bin/env bash

GREEN='\033[0;32m'
RESET='\033[0m'

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks/*; do
  [ -r "${file}" ] && [ -e "${file}" ] && rm -f ${HOME}/.`basename ${file}` && ln -s ${file} ${HOME}/.`basename ${file}`
done

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/install/*; do
  [ -r "${file}" ] && [ -e "${file}" ] && "${file}"
done

if [ `uname` == 'Darwin' ]; then
  brew cleanup
fi
