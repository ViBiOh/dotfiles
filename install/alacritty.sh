#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if command -v brew > /dev/null 2>&1; then
    brew cask reinstall alacritty
    ln -f -s /Applications/Alacritty.app/Contents/MacOS/alacritty "${HOME}/opt/bin/alacritty"
  fi
}

main
