#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  packages_install "tmux"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "reattach-to-user-namespace"
  fi
}
