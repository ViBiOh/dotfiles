#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    rm -rf "${HOME}/Caches/JetBrains"
  fi
}

install() {
  packages_install "goland"

  "$(script_dir)/../goland/init.sh"
}
