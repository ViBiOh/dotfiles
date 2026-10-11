#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.iredis_history"
}

install() {
  source "${DOTFILES_DIR}/sources/_python.sh"

  if command -v uv >/dev/null 2>&1; then
    uv tool install --managed-python --upgrade "iredis"
  fi
}
