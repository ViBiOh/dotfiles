#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sed_inplace() {
  if [[ "${IS_MACOS}" = true ]]; then
    sed -i '' "${@}"
  else
    sed -i "${@}"
  fi
}

main() {
  if command -v brew > /dev/null 2>&1; then
    echo "brew not found, no action"
    exit
  fi

  brew cask install alacritty
}

main
