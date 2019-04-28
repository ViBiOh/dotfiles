#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if command -v brew > /dev/null 2>&1; then
    brew install python
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq python
  fi

  if command -v python > /dev/null 2>&1; then
    mkdir -p "${HOME}/opt/python"
    source "${SCRIPT_DIR}/../sources/_python"
  fi

  if command -v pip > /dev/null 2>&1; then
    pip install --user --upgrade pip
  fi
}

main
