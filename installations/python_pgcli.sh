#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".config/pgcli/config"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink

  rm -rf "${HOME}/.pgpass"
  rm -rf "${HOME}/.psql_history"
  rm -rf "${HOME}/.config/pgcli"
}

install() {
  source "${DOTFILES_DIR}/sources/_python.sh"

  if ! command -v pip >/dev/null 2>&1; then
    var_error "pip is required"
    exit
  fi

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "pgcli"
  elif command -v apt-get >/dev/null 2>&1; then
    packages_install "libpq-dev"
    pip install "pgcli"
  fi
}

credentials() {
  if ! command -v pass >/dev/null 2>&1 || ! [[ -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]]; then
    return
  fi

  extract_secret "infra/pgpass" ".pgpass"
}
