#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home "${DOTFILES_DIR}/symlinks/alacritty.toml"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  if package_exists "alacritty"; then
    packages_install_desktop "alacritty"
  fi
}
