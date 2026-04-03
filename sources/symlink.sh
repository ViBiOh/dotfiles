#!/usr/bin/env bash

symlink_home() {
  local BASENAME_FILE
  BASENAME_FILE="$(basename "${1}")"

  local SYMLINK_TARGET="${HOME}/${2:-.}${BASENAME_FILE}"

  rm -rf "${SYMLINK_TARGET}"

  local RESOLVED_DIRNAME
  RESOLVED_DIRNAME=$(cd "$(dirname "${1}")" && pwd)

  if [[ ${SYMLINK_ONLY_CLEAN:-} != "true" ]]; then
    if ! [[ -e "$(dirname "${SYMLINK_TARGET}")" ]]; then
      mkdir -p "$(dirname "${SYMLINK_TARGET}")"
    fi

    [[ -r ${1} ]] && [[ -e ${1} ]] && ln -s "${RESOLVED_DIRNAME}/${BASENAME_FILE}" "${SYMLINK_TARGET}"
  fi
}
