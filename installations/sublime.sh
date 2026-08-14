#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo rm -rf "${HOME}/Library/Caches/Sublime Text"
    sudo rm -rf "${HOME}/Library/Caches/Sublime Merge"
  fi
}

install() {
  if package_exists "sublime-merge@dev"; then
    packages_install_desktop "sublime-merge@dev"
  elif package_exists "sublime-merge"; then
    packages_install_desktop "sublime-merge"
  fi

  local SUBLIME_TEXT_VERSION
  SUBLIME_TEXT_VERSION="$(sublime_text_dev_version)"

  local SUBLIME_TEXT_STABLE_VERSION
  SUBLIME_TEXT_STABLE_VERSION="$(sublime_text_stable_version)"

  if [[ ${SUBLIME_TEXT_VERSION} < ${SUBLIME_TEXT_STABLE_VERSION} ]]; then
    SUBLIME_TEXT_VERSION="${SUBLIME_TEXT_STABLE_VERSION}"
  fi

  sublime_text_install "${SUBLIME_TEXT_VERSION}"

  if command -v subl >/dev/null 2>&1; then
    "${DOTFILES_DIR}/tools/sublime/init.sh"
  fi
}
