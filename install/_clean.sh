#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  sudo rm -rf "${HOME}/.ansible-vault-pass"
  sudo rm -rf "${HOME}/.config"
  sudo rm -rf "${HOME}/.fzf.bash"
  sudo rm -rf "${HOME}/.terraformrc"
  sudo rm -rf "${HOME}/opt"

  mkdir -p "${HOME}/opt/bin"
}

main
