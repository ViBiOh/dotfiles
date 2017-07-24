#!/usr/bin/env sh

set -e

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks/*; do
  [ -r "${file}" ] && [ -f "${file}" ] && rm -f ${HOME}/.`basename ${file}` && ln -s ${file} ${HOME}/.`basename ${file}`
done

rm -rf ${HOME}/.vim/snippets
ln -s ${HOME}/code/src/github.com/ViBiOh/dotfiles/snippets ${HOME}/.vim/snippets
