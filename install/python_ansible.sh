#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.ansible"*
}

credentials() {
  if ! command -v pass > /dev/null 2>&1; then
    exit
  fi

  local PASS_DIR="${PASSWORD_STORE_DIR-~/.password-store}"
  local ANSIBLE_PASS="$(find "${PASS_DIR}" -name "*ansible.gpg" -print | sed -e "s|${PASS_DIR}/\(.*\)\.gpg$|\1|")"

  if [[ "$(echo "${ANSIBLE_PASS}" | wc -l)" -eq 1 ]]; then
    pass show "${ANSIBLE_PASS}" > "${HOME}/.ansible-vault-pass"
  fi
}

install() {
  local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/../sources/_python"

  if ! command -v pip > /dev/null 2>&1; then
    echo "pip is required"
    exit
  fi

  pip install --user ansible ansible-lint jmespath
}
