#!/usr/bin/env bash

symlink_home() {
  local BASENAME_FILE
  BASENAME_FILE="$(basename "${1}")"

  rm -f "${HOME}/.${BASENAME_FILE}"

  local RESOLVED_DIRNAME
  RESOLVED_DIRNAME=$(cd "$(dirname "${1}")" && pwd)

  if [[ ${SYMLINK_ONLY_CLEAN:-} != "true" ]]; then
    [[ -r ${1} ]] && [[ -e ${1} ]] && ln -s "${RESOLVED_DIRNAME}/${BASENAME_FILE}" "${HOME}/.${BASENAME_FILE}"
  fi
}
