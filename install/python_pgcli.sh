#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  source "${SCRIPT_DIR}/../sources/_python"

  if ! command -v pip > /dev/null 2>&1; then
    echo "pip is required"
    exit
  fi

  if command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq libpq-dev
  fi

  pip install --user pgcli

  if command -v pgcli > /dev/null 2>&1; then
    mkdir -p "${HOME}/.config/pgcli"

    echo '[main]
multi_line = True
auto_expand = True
row_limit = 100' > "${HOME}/.config/pgcli/config"
  fi
}

main
