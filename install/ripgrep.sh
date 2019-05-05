#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  local RIPGREP_VERSION=0.10.0

  if command -v brew > /dev/null 2>&1; then
    brew tap burntsushi/ripgrep https://github.com/BurntSushi/ripgrep.git
    brew install ripgrep-bin
  elif command -v apt-get > /dev/null 2>&1 && [ $(uname -m) = 'x86_64' ]; then
    set +e
    sudo apt-cache show ripgrep > /dev/null 2>&1
    ripgrep=$?
    set -e

    if [[ "${ripgrep}" -eq 0 ]]; then
      sudo apt-get install -y -qq ripgrep
    fi
  fi
}

main
