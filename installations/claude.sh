#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.claude"
}

install() {
  packages_install "claude-code"

  "${DOTFILES_DIR}/tools/claude/init.sh"
}
