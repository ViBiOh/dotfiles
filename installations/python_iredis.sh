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
  rm -rf "${HOME}/.iredis_history"
}

install() {
  source "$(script_dir)/../sources/_python.sh"

  if ! command -v pip >/dev/null 2>&1; then
    var_error "pip is required"
    exit
  fi

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "iredis"
  elif command -v apt-get >/dev/null 2>&1; then
    pip install "iredis"
  fi
}
