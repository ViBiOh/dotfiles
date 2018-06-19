#!/usr/bin/env bash

echo "${GREEN}Pgcli${RESET}"

if [ `uname` == 'Darwin' ]; then
  brew reinstall pgcli
fi

if command -v pgcli > /dev/null 2>&1; then
  mkdir -p "${HOME}/.config/pgcli"
  ln -s "${HOME}/.pgclirc" "${HOME}/.config/pgcli/config"
fi
