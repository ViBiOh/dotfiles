#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if command -v brew > /dev/null 2>&1; then
    brew install shellcheck
  elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed shellcheck
  fi
}
