#!/usr/bin/env bash

set -e
set -u

echo "---------"
echo "- Pgcli -"
echo "---------"

if command -v pip > /dev/null 2>&1; then
  pip install pgcli
fi

if command -v pgcli > /dev/null 2>&1; then
  mkdir -p "${HOME}/.config/pgcli"
  ln -s -f "${HOME}/.pgclirc" "${HOME}/.config/pgcli/config"
fi
