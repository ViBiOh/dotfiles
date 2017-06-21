#!/bin/sh

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/.*; do
  [ -r "${file}" ] && [ -f "${file}" ] && source ${file}
done

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/*[!.md]; do
  [ -r "${file}" ] && [ -f "${file}" ] && cp ${file} ${HOME}/.`basename ${file}`
done

echo Machine is `uptime -p`
