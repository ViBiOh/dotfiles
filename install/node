#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if command -v npm > /dev/null 2>&1; then
    npm cache clean --force
  fi

  rm -rf "${HOME}/.babel.json"
  rm -rf "${HOME}/.node-gyp"
  rm -rf "${HOME}/.node_repl_history"
  rm -rf "${HOME}/.npm"
  rm -rf "${HOME}/.v8flags."*
}

install() {
  if ! command -v git > /dev/null 2>&1; then
    printf "git is required\n"
    exit
  fi

  if ! command -v make > /dev/null 2>&1; then
    printf "make is required\n"
    exit
  fi

  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local NODE_VERSION="latest"

  rm -rf "${HOME}/n-install"
  git clone --depth 1 https://github.com/tj/n.git "${HOME}/n-install"
  (cd "${HOME}/n-install" && PREFIX="${HOME}/opt" make install)
  rm -rf "${HOME}/n-install"

  mkdir -p "${HOME}/opt/node"
  source "${SCRIPT_DIR}/../sources/node"
  n "${NODE_VERSION}"

  if ! command -v npm > /dev/null 2>&1; then
    return
  fi

  npm install --ignore-scripts -g npm npm-check-updates node-gyp
}
