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

  local CONFIG_DIR
  CONFIG_DIR="${HOME}/.claude"

  mkdir -p "${CONFIG_DIR}"

  rm -rf "${CONFIG_DIR}/CLAUDE.md"
  rm -rf "${CONFIG_DIR}/settings.json"

  ln -s "${SCRIPT_DIR}/CLAUDE.md" "${CONFIG_DIR}/CLAUDE.md"
  ln -s "${SCRIPT_DIR}/settings.json" "${CONFIG_DIR}/settings.json"
}

main "${@}"
