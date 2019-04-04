#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  rm -rf "${HOME}/opt" "${HOME}/.config"
  mkdir -p "${HOME}/opt/bin"
}

main
