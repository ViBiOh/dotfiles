#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if ! command -v git > /dev/null 2>&1; then
    echo "git is required"
    exit
  fi

  if ! command -v make > /dev/null 2>&1; then
    echo "make is required"
    exit
  fi

  local NODE_VERSION="latest"

  rm -rf "${HOME}/n-install"
  git clone --depth 1 https://github.com/tj/n.git "${HOME}/n-install"
  pushd "${HOME}/n-install"
  PREFIX="${HOME}/opt" make install
  popd
  rm -rf "${HOME}/n-install"

  mkdir -p "${HOME}/opt/node"
  source "${SCRIPT_DIR}/../sources/node"
  n "${NODE_VERSION}"

  if command -v npm > /dev/null 2>&1; then
    npm install --ignore-scripts -g npm npm-check-updates node-gyp
  fi
}

main
