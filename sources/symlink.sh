#!/usr/bin/env bash

symlink_home() {
  local SYMLINK_SOURCE="${DOTFILES_DIR}/symlinks/${1}"
  local SYMLINK_TARGET="${HOME}/${1}"

  rm -rf "${SYMLINK_TARGET}"

  if [[ ${SYMLINK_ONLY_CLEAN:-} != "true" ]]; then
    if ! [[ -e "$(dirname "${SYMLINK_TARGET}")" ]]; then
      mkdir -p "$(dirname "${SYMLINK_TARGET}")"
    fi

    [[ -r ${SYMLINK_SOURCE} ]] && [[ -e ${SYMLINK_SOURCE} ]] && ln -s "${SYMLINK_SOURCE}" "${SYMLINK_TARGET}"
  fi
}
