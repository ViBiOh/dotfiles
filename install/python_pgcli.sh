#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/../sources/_python"

  if ! command -v pip > /dev/null 2>&1; then
    echo "pip is required"
    exit
  fi

  if command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq libpq-dev
  fi

  if [[ "$(pip install --help | grep prefer-binary | wc -l)" -eq 1 ]]; then
    pip install --user --prefer-binary pgcli
  else
    pip install --user pgcli
  fi

  if ! command -v pgcli > /dev/null 2>&1; then
    return
  fi

  mkdir -p "${HOME}/.config/pgcli"

  echo "[main]
multi_line = True
auto_expand = True
row_limit = 100" > "${HOME}/.config/pgcli/config"
}
