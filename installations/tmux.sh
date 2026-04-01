#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home "${DOTFILES_DIR}/symlinks/tmux.conf"
  symlink_home "${DOTFILES_DIR}/symlinks/tmux-osx.conf"
  symlink_home "${DOTFILES_DIR}/symlinks/tmux_stock"
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
