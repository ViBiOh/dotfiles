#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.python_history"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    rm -rf "${HOME}/Library/Caches/pip"
    rm -rf "${HOME}/Library/Caches/pip-tools"
  fi
}

install() {

  if package_exists "python"; then
    packages_install "python"
  fi

  if package_exists "python-debian"; then
    packages_install "python-debian"
  fi

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

  source "${DOTFILES_DIR}/sources/__first.sh"
  source "${DOTFILES_DIR}/sources/_python.sh"

  if ! command -v pip >/dev/null 2>&1; then
    return
  fi

  pip install --upgrade "pip"
}
