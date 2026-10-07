#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".npmrc"
}

clean() {
  if command -v npm >/dev/null 2>&1; then
    npm cache clean --force
  fi

  rm -rf "${HOME}/.babel.json"
  rm -rf "${HOME}/.node-gyp"
  rm -rf "${HOME}/.node_repl_history"
  rm -rf "${HOME}/.npm"
  rm -rf "${HOME}/.v8flags."*

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    rm -rf "${HOME}/Library/Caches/Yarn"
  fi

  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  if package_exists "node"; then
    packages_install "node"
  elif package_exists "nodejs"; then
    packages_install "nodejs"
  fi

  mkdir -p "${HOME}/opt/node/lib"
  source "${DOTFILES_DIR}/sources/node.sh"

  if ! command -v npm >/dev/null 2>&1; then
    return
  fi

  npm install --ignore-scripts --global "npm"
}
