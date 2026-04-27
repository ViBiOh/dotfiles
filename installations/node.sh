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

  if ! command -v git >/dev/null 2>&1; then
    var_error "git is required"
    exit
  fi

  if ! command -v make >/dev/null 2>&1; then
    var_error "make is required"
    exit
  fi

  local NODE_VERSION="latest"

  rm -rf "${HOME}/n-install"
  git clone --depth 1 "https://github.com/tj/n.git" "${HOME}/n-install"
  (cd "${HOME}/n-install" && PREFIX="${HOME}/opt" make install)
  rm -rf "${HOME}/n-install"

  # Fix n with curl --compressed
  sed "s|curl --silent --compressed|curl --silent|" "${HOME}/opt/bin/n" >"${HOME}/opt/bin/n-fixed"
  rm "${HOME}/opt/bin/n"
  mv "${HOME}/opt/bin/n-fixed" "${HOME}/opt/bin/n"
  chmod +x "${HOME}/opt/bin/n"

  mkdir -p "${HOME}/opt/node"
  source "${DOTFILES_DIR}/sources/__binary.sh"
  source "${DOTFILES_DIR}/sources/node.sh"
  n "${NODE_VERSION}"

  if ! command -v npm >/dev/null 2>&1; then
    return
  fi

  mkdir -p "${HOME}/opt/node/lib"

  npm install --ignore-scripts --global "npm"
}
