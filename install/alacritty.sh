#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if ! command -v brew > /dev/null 2>&1; then
    echo "brew not found"
    exit
  fi

  brew cask install alacritty

  ln -s /Applications/Alacritty.app/Contents/MacOS/alacritty "${HOME}/opt/bin/alacritty"
}

main
