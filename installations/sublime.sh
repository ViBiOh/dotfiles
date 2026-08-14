#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo rm -rf "${HOME}/Library/Caches/Sublime Text"
    sudo rm -rf "${HOME}/Library/Caches/Sublime Merge"
  fi
}

install() {
  if package_exists "sublime-text@dev"; then
    packages_install_desktop "sublime-text@dev"
  elif package_exists "sublime-text"; then
    packages_install_desktop "sublime-text"
  fi

  if package_exists "sublime-merge@dev"; then
    packages_install_desktop "sublime-merge@dev"
  elif package_exists "sublime-merge"; then
    packages_install_desktop "sublime-merge"
  fi

  if command -v subl >/dev/null 2>&1; then
    "${DOTFILES_DIR}/tools/sublime/init.sh"
  fi
}
