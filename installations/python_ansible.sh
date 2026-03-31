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

symlink() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(script_dir)"

  symlink_home "${SCRIPT_DIR}/../symlinks/ansible.cfg"
  symlink_home "${SCRIPT_DIR}/../symlinks/ansible_vault_pass.sh"
}

clean() {
  rm -rf "${HOME}/.ansible/"
  rm -rf "${HOME}/.ansible"*[^.cfg]

  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  source "$(script_dir)/../sources/_python.sh"

  if ! command -v pip >/dev/null 2>&1; then
    var_error "pip is required"
    exit
  fi

  pip install "ansible" "passlib" "ansible-lint" "jmespath" "yamllint"
}
