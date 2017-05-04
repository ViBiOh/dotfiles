#!/bin/sh

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/.*; do
  [ -r "${file}" ] && [ -f "${file}" ] && source ${file}
done

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/*; do
  [ -r "${file}" ] && [ -f "${file}" ] && [ `basename ${file}` != "README.md" ] && [ `basename ${file}` != "LICENSE.md" ] && cp ${file} ${HOME}/.`basename ${file}`
done

echo Machine is up since `uptime | awk '{print $3 $4}' | sed 's|,$||'`
