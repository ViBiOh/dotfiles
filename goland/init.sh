#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

script_dir() {
  local FILE_SOURCE="${BASH_SOURCE[0]}"

  if [[ -L ${FILE_SOURCE} ]]; then
    dirname "$(readlink "${FILE_SOURCE}")"
  else
    (
      cd "$(dirname "${FILE_SOURCE}")" && pwd
    )
  fi
}

main() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(script_dir)"

  local GOLAND_VERSION="GoLand2024.3"

  local CONFIG_DIR="${SCRIPT_DIR}/config"
  local TARGET_DIR="${HOME}/Library/Application Support/JetBrains/${GOLAND_VERSION}"

  while IFS= read -r -d '' file; do
    local TARGET_FILE="${file/#${CONFIG_DIR}/${TARGET_DIR}}"

    local TARGET_FILE_DIR
    TARGET_FILE_DIR="$(dirname "${TARGET_FILE}")"

    if ! [[ -d "${TARGET_FILE_DIR}" ]]; then
      mkdir -p "${TARGET_FILE_DIR}"
    fi

    if [[ -e "${TARGET_FILE}" ]]; then
      rm -f "${TARGET_FILE}"
    fi

    ln -s "${file}" "${TARGET_FILE}"
  done < <(find "${CONFIG_DIR}" -type f -print0)
}

main "${@}"
