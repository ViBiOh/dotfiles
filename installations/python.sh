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
  rm -rf "${HOME}/.python_history"
}

install() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(script_dir)"

  packages_install "python"

  if package_exists "python-pip"; then
    packages_install "python-pip"
  fi

  if command -v brew >/dev/null 2>&1; then
    brew unlink "python" && brew link "python"
  fi

  if ! command -v python >/dev/null 2>&1; then
    return
  fi

  mkdir -p "${HOME}/opt/python"

  python3 -m venv "${HOME}/opt/python/venv"

  source "${SCRIPT_DIR}/../sources/_first.sh"
  source "${SCRIPT_DIR}/../sources/_python.sh"

  if ! command -v pip >/dev/null 2>&1; then
    return
  fi

  pip install --upgrade "pip"
}
