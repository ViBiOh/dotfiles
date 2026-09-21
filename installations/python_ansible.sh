#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".ansible.cfg"
  symlink_home ".ansible_vault_pass.sh"
}

clean() {
  rm -rf "${HOME}/.ansible/"
  rm -rf "${HOME}/.ansible"*[^.cfg]

  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  source "${DOTFILES_DIR}/sources/_python.sh"

  if ! command -v uv >/dev/null 2>&1; then
    var_error "uv is required"
    exit
  fi

  uv pip install "ansible" "passlib" "ansible-lint" "jmespath" "yamllint"
}
