#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo rm -rf "${HOME}/Library/Caches/Sublime Text"
    sudo rm -rf "${HOME}/Library/Caches/Sublime Merge"
  fi
}

install() {
  local SUBLIME_TEXT_VERSION
  SUBLIME_TEXT_VERSION="$(sublime_text_dev_version)"

  local SUBLIME_TEXT_STABLE_VERSION
  SUBLIME_TEXT_STABLE_VERSION="$(sublime_text_stable_version)"

  if [[ ${SUBLIME_TEXT_VERSION} < ${SUBLIME_TEXT_STABLE_VERSION} ]]; then
    SUBLIME_TEXT_VERSION="${SUBLIME_TEXT_STABLE_VERSION}"
  fi

  sublime_text_install "${SUBLIME_TEXT_VERSION}"

  local SUBLIME_MERGE_VERSION
  SUBLIME_MERGE_VERSION="$(sublime_merge_dev_version)"

  local SUBLIME_MERGE_STABLE_VERSION
  SUBLIME_MERGE_STABLE_VERSION="$(sublime_merge_stable_version)"

  if [[ ${SUBLIME_MERGE_VERSION} < ${SUBLIME_MERGE_STABLE_VERSION} ]]; then
    SUBLIME_MERGE_VERSION="${SUBLIME_MERGE_STABLE_VERSION}"
  fi

  sublime_merge_install "${SUBLIME_MERGE_VERSION}"

  if command -v subl >/dev/null 2>&1; then
    "${DOTFILES_DIR}/tools/sublime/init.sh"
  fi
}
