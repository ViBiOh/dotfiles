#!/bin/sh

for file in ${HOME}/code/dotfiles/.*; do
  [[ -r "${file}" ]] && [[ -f "${file}" ]] && source "${file}"
done

for file in ${HOME}/code/dotfiles/*; do
  [[ -r "${file}" ]] && [[ -f "${file}" ]] && cp ${file} ${HOME}/.`basename ${file}`
done
