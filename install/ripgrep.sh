#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if command -v brew > /dev/null 2>&1; then
    brew tap "burntsushi/ripgrep" "https://github.com/BurntSushi/ripgrep.git"
    brew install ripgrep-bin
  elif command -v apt-get > /dev/null 2>&1 && [[ "$(uname -m | tr "[:upper:]" "[:lower:]")" = "x86_64" ]]; then
    sudo apt-get install -y -qq ripgrep
  fi
}
