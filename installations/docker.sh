#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "container"

    ln -s "${BREW_PREFIX}/bin/container" "${HOME}/opt/bin/docker"
  fi
}
