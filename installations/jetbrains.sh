#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if command -v gpgconf >/dev/null 2>&1; then
    gpgconf --kill gpg-agent
  fi
}

install() {
  packages_install "goland"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    rm -rf "${HOME}/Library/JetBrains"
  fi
}
