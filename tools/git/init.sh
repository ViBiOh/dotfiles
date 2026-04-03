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

  symlink_home "${SCRIPT_DIR}/gitconfig"
  symlink_home "${SCRIPT_DIR}/gitconfig_work"
  symlink_home "${SCRIPT_DIR}/gitignore_global"

  # https://git-scm.com/docs/git#Documentation/git.txt---list-cmdsltgroupgtltgroupgt82308203
  ln -s -f "${SCRIPT_DIR}/git-coco.sh" "${HOME}/opt/bin/git-coco"
}

main "${@:-}"
