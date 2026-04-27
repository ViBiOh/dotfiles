#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo rm -rf "${HOME}/Library/Caches/Sublime Text"
    sudo rm -rf "${HOME}/Library/Caches/Sublime Merge"
  fi
}

install() {
  if package_exists "sublime-merge"; then
    packages_install_desktop "sublime-merge"
  fi

  local SUBLIME_TEXT_VERSION
  SUBLIME_TEXT_VERSION="$(curl --disable --silent --show-error --location --max-time 30 "https://www.sublimetext.com/updates/4/dev_update_check" | jq ".latest_version")"

  local SUBLIME_TEXT_STABLE_VERSION
  SUBLIME_TEXT_STABLE_VERSION="$(curl --disable --silent --show-error --location --max-time 30 "https://www.sublimetext.com/updates/4/stable_update_check" | jq ".latest_version")"

  if [[ ${SUBLIME_TEXT_VERSION} < ${SUBLIME_TEXT_STABLE_VERSION} ]]; then
    SUBLIME_TEXT_VERSION="${SUBLIME_TEXT_STABLE_VERSION}"
  fi

  sublime_install "${SUBLIME_TEXT_VERSION}"

  if command -v subl >/dev/null 2>&1; then
    "${DOTFILES_DIR}/tools/sublime/init.sh"
  fi
}
