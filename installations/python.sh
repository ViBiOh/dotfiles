#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.python_history"
  rm -rf "${HOME}/opt/python"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    rm -rf "${HOME}/Library/Caches/pip"
    rm -rf "${HOME}/Library/Caches/pip-tools"
    rm -rf "${HOME}/Library/Caches/uv"
  else
    rm -rf "${HOME}/.cache/uv"
  fi
}

install() {
  if package_exists "python"; then
    packages_install "python"
  fi

  if package_exists "python-debian"; then
    packages_install "python-debian"
  fi

  if package_exists "uv"; then
    packages_install "uv"
  fi

  if command -v brew >/dev/null 2>&1; then
    brew unlink "python" && brew link "python"
  fi

  if ! command -v python >/dev/null 2>&1 || ! command -v uv >/dev/null 2>&1; then
    return
  fi

  mkdir -p "${HOME}/opt/python"
  uv venv "${HOME}/opt/python/venv"

  source "${DOTFILES_DIR}/sources/__binary.sh"
  source "${DOTFILES_DIR}/sources/_python.sh"
}
