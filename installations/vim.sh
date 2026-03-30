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

  symlink_home "${SCRIPT_DIR}/../symlinks/vimrc"
}

clean() {
  rm -rf "${HOME}/.vim/"
  rm -rf "${HOME}/.viminfo"

  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  packages_install "vim"
}
