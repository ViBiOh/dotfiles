#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if ! command -v pip > /dev/null 2>&1; then
    echo "pip is required"
    exit
  fi

  source "${SCRIPT_DIR}/../sources/_python"

  pip install --user asciinema
}

main
