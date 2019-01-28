#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if command -v easy_install > /dev/null 2>&1; then
    easy_install --user pip
  fi

  if command -v pip > /dev/null 2>&1; then
    pip install --user --upgrade pip
    pip install --user pgcli
  fi

  if command -v pgcli > /dev/null 2>&1; then
    mkdir -p "${HOME}/.config/pgcli"

    echo '[main]
multi_line = True
auto_expand = True
row_limit = 100' > "${HOME}/.config/pgcli/config"
  fi
}

main
