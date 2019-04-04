#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if ! command -v pip > /dev/null 2>&1; then
    echo "asciinema requires pip"
    exit
  fi

  source "${SCRIPT_DIR}/../sources/_python"

  pip install --user asciinema
}

main
