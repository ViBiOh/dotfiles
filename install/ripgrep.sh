#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  local RIPGREP_VERSION=0.10.0

  if [[ "${IS_MACOS}" == true ]]; then
    brew tap burntsushi/ripgrep https://github.com/BurntSushi/ripgrep.git
    brew install ripgrep-bin
  elif command -v apt-get > /dev/null 2>&1 && [ $(uname -m) == 'x86_64' ]; then
    set +e
    sudo apt-cache show ripgrep > /dev/null 2>&1
    ripgrep=$?
    set -e

    if [[ "${ripgrep}" -eq 0 ]]; then
      sudo apt-get install -y -qq ripgrep
    else
      curl -LO "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep_${RIPGREP_VERSION}_amd64.deb"
      sudo dpkg -i "ripgrep_${RIPGREP_VERSION}_amd64.deb"
      rm -rf "ripgrep_${RIPGREP_VERSION}_amd64.deb"
    fi
  fi
}

main
