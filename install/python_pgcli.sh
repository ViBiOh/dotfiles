#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if ! command -v pip > /dev/null 2>&1; then
    echo "pgcli requires pip"
    exit
  fi

  if command -v apt-get > /dev/null 2>&1; then
    if [[ "${DOTFILES_NO_SUDO:-}" != "true" ]]; then
      sudo apt-get install -y -qq libpq-dev
    fi
  fi

  source "${SCRIPT_DIR}/../sources/_python"

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
