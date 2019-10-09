#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    local PKG="${HOME}/Library/Application Support/Sublime Text 3/Packages"
  else
    local PKG="${HOME}/.config/sublime-text-3/Packages"
  fi

  local PKG_USER="${PKG}/User"
  local GO_PLUGIN_NAME="SublimeGo"

  mkdir -p "${PKG_USER}"
  rm -rf "${PKG_USER:?}"/* "${PKG:?}/${GO_PLUGIN_NAME}"

  cp -r "${SCRIPT_DIR}/${GO_PLUGIN_NAME}" "${PKG}/${GO_PLUGIN_NAME}"
  cp "${SCRIPT_DIR}/snippets/"* "${PKG_USER}/"
  cp "${SCRIPT_DIR}/settings/"* "${PKG_USER}/"

  if command -v go > /dev/null 2>&1; then
    go get -u golang.org/x/tools/cmd/gopls
    go get -u golang.org/x/tools/cmd/gotype
  fi

  if command -v npm > /dev/null 2>&1; then
    npm install -g prettier javascript-typescript-langserver
  fi
}

main
