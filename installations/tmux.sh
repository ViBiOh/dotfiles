#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

script_dir() {
  local FILE_SOURCE="${BASH_SOURCE[0]}"

  if [[ -L ${FILE_SOURCE} ]]; then
    dirname "$(readlink "${FILE_SOURCE}")"
  else
    (
      cd "$(dirname "${FILE_SOURCE}")" && pwd
    )
  fi
}

symlink() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(script_dir)"

  symlink_home "${SCRIPT_DIR}/../symlinks/tmux.conf"
  symlink_home "${SCRIPT_DIR}/../symlinks/tmux-osx.conf"
  symlink_home "${SCRIPT_DIR}/../symlinks/tmux_stock"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  packages_install "tmux"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "reattach-to-user-namespace"
  fi
}
