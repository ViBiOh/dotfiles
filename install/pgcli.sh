#!/usr/bin/env bash

set -e
set -u

echo "---------"
echo "- Pgcli -"
echo "---------"

if ! command -v pip > /dev/null 2>&1 && [ `uname -s` == 'Darwin' ]; then
  sudo easy_install pip
fi

if command -v pip > /dev/null 2>&1; then
  pip install pgcli
fi

if command -v pgcli > /dev/null 2>&1; then
  mkdir -p "${HOME}/.config/pgcli"

  echo '[main]
multi_line = True
auto_expand = True
row_limit = 100' > "${HOME}/.config/pgcli/config"
fi
