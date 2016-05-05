#!/bin/sh

for file in ${HOME}/code/dotfiles/.*; do
  [ -r "${file}" ] && [ -f "${file}" ] && source ${file}
done

for file in ${HOME}/code/dotfiles/*; do
  [ -r "${file}" ] && [ -f "${file}" ] && [ `basename ${file}` != "README.md" ] && cp ${file} ${HOME}/.`basename ${file}`
done

for file in ${HOME}/*_docker_profile; do
  [ -r "${file}" ] && [ -f "${file}" ] && source ${file}
done