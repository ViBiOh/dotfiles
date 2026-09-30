#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home "Library/Application Support/com.mitchellh.ghostty/config"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  if package_exists "ghostty"; then
    packages_install_desktop "ghostty"
  fi
}
