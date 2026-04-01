#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home "${DOTFILES_DIR}/symlinks/ripgreprc"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  packages_install "ripgrep"
}
