#!/usr/bin/env bash

zip_split() {
  if [[ ${#} -lt 3 ]]; then
    var_red "Usage: zip_split SPLIT_SIZE ARCHIVE_PATH FILE_PATH"
    return 1
  fi

  local SPLIT_SIZE="${1}"
  shift

  local ARCHIVE_PATH="${1}"
  shift

  local FILE_PATH="${1}"
  shift

  zip -s "${SPLIT_SIZE}" "${ARCHIVE_PATH}" "${FILE_PATH}"
}

zip_join() {
  if [[ ${#} -lt 2 ]]; then
    var_red "Usage: zip_join ARCHIVE_PATH JOINED_PATH"
    return 1
  fi

  local ARCHIVE_PATH="${1}"
  shift

  local JOINED_PATH="${1}"
  shift

  zip -F "${ARCHIVE_PATH}" --out "${JOINED_PATH}"
}
