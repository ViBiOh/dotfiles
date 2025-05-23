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

browse_folder() {
  local NAME_PREFIX=${2-}

  while IFS= read -r -d '' dir; do
    (
      cd "${dir}" || return
      NAME_PREFIX=${NAME_PREFIX} sublime_add_project
    )
  done < <(find "${1}" -type d -maxdepth 1 -print0)
}

main() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(script_dir)"

  local PROJECT_FOLDER="${SCRIPT_DIR}/projects"

  if [[ -e "${SCRIPT_DIR}/../scripts/meta" ]]; then
    source "${SCRIPT_DIR}/../scripts/meta" && meta_init "var" "git"
  else
    printf -- "scripts' folder not found"
    return 1
  fi

  source "${SCRIPT_DIR}/../sources/sublime.sh"

  rm -rf "${PROJECT_FOLDER}"
  mkdir -p "${PROJECT_FOLDER}"

  browse_folder "${HOME}/code"

  if [[ -d "${HOME}/workspace" ]]; then
    browse_folder "$(readlink -f "${HOME}/workspace")" "work"
  fi
}

main "${@}"
