#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if command -v brew > /dev/null 2>&1; then
    brew cask reinstall firefox
  if command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed firefox
  fi
}

main
