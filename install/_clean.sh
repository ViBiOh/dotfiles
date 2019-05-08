#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  sudo rm -rf "${HOME}/opt" "${HOME}/.config" "${HOME}/.fzf.bash"
  mkdir -p "${HOME}/opt/bin"
}

main
