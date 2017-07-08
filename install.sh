#!/bin/sh

set -e

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks/*; do
  [ -r "${file}" ] && [ -f "${file}" ] && rm ${HOME}/.`basename ${file}` && ln -s ${file} ${HOME}/.`basename ${file}`
done
