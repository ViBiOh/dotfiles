#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if [[ -h "${HOME}/opt/bin/docker" ]]; then
    rm "${HOME}/opt/bin/docker"
  fi
}

install() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "container"

  if ! [[ -h "${HOME}/opt/bin/docker" ]]; then
    ln -s "${BREW_PREFIX}/bin/container" "${HOME}/opt/bin/docker"
  fi
  fi
}
