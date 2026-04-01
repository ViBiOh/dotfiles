#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.iredis_history"
}

install() {
  source "${DOTFILES_DIR}/sources/_python.sh"

  if ! command -v pip >/dev/null 2>&1; then
    var_error "pip is required"
    exit
  fi

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "iredis"
  elif command -v apt-get >/dev/null 2>&1; then
    pip install "iredis"
  fi
}
