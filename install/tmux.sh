#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if [[ "${IS_MACOS}" = true ]]; then
    brew install \
      tmux \
      reattach-to-user-namespace
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq tmux
  fi
}

main
