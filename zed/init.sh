#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

if [[ ${TRACE:-0} == "1" ]]; then
  set -o xtrace
fi

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

  local ZED_CONFIG_FOLDER="${HOME}/.config/zed"
  local ZED_SNIPPETS_FOLDER="${ZED_CONFIG_FOLDER}/snippets"

  sudo rm -rf "${ZED_CONFIG_FOLDER}"
  mkdir -p "${ZED_SNIPPETS_FOLDER}"

  ln -s "${SCRIPT_DIR}/settings.json" "${ZED_CONFIG_FOLDER}/"
  ln -s "${SCRIPT_DIR}/keymap.json" "${ZED_CONFIG_FOLDER}/"
  ln -s "${SCRIPT_DIR}/snippets/"*.json "${ZED_SNIPPETS_FOLDER}/"
}

main "${@}"
