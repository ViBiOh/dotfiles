#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if ! command -v pip > /dev/null 2>&1; then
    echo "asciinema requires pip"
    exit
  fi

  source "${SCRIPT_DIR}/../sources/_python"

  pip install --user asciinema
}

main
