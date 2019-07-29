#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  sudo rm -rf "${HOME}/.config"
  sudo rm -rf "${HOME}/opt"

  mkdir -p "${HOME}/opt/bin"
}

main
