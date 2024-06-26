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

clean() {
  rm -rf "${HOME}/.pgpass"
  rm -rf "${HOME}/.psql_history"
  rm -rf "${HOME}/.config/pgcli"
}

install() {
  source "$(script_dir)/../sources/_python.sh"

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

  if ! command -v pgcli >/dev/null 2>&1; then
    return
  fi

  mkdir -p "${HOME}/.config/pgcli"

  echo "[main]
multi_line = True
auto_expand = True
row_limit = 100
log_level = ERROR
" >"${HOME}/.config/pgcli/config"
}

credentials() {
  if ! command -v pass >/dev/null 2>&1 || ! [[ -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]]; then
    return
  fi

  extract_secret "infra/pgpass" ".pgpass"
}
