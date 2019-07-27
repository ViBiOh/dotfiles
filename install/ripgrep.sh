#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if command -v brew > /dev/null 2>&1; then
    brew tap "burntsushi/ripgrep" "https://github.com/BurntSushi/ripgrep.git"
    brew install ripgrep-bin
  elif command -v apt-get > /dev/null 2>&1 && [ $(uname -m) = 'x86_64' ]; then
    set +e
    sudo apt-cache show ripgrep > /dev/null 2>&1
    ripgrep=$?
    set -e

    if [[ "${ripgrep}" -eq 0 ]]; then
      sudo apt-get install -y -qq ripgrep
    fi
  elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed ripgrep
  fi
}

main
