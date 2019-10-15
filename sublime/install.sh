#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_plugin() {
  local PLUGIN_NAME="${1}"

  rm -rf "${PKG:?}/${PLUGIN_NAME}"
  cp -r "${SCRIPT_DIR}/${PLUGIN_NAME}" "${PKG}/${PLUGIN_NAME}"
}

main() {
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    local PKG="${HOME}/Library/Application Support/Sublime Text 3/Packages"
  else
    local PKG="${HOME}/.config/sublime-text-3/Packages"
  fi

  local PKG_USER="${PKG}/User"
  rm -rf "${PKG_USER:?}"/*
  mkdir -p "${PKG_USER}"

  install_plugin SublimeGo
  install_plugin SublimeTerraform

  cp "${SCRIPT_DIR}/snippets/"* "${PKG_USER}/"
  cp "${SCRIPT_DIR}/settings/"* "${PKG_USER}/"

  if command -v go > /dev/null 2>&1; then
    go get -u golang.org/x/tools/cmd/gopls
    go get -u golang.org/x/tools/cmd/gotype
  fi

  if command -v npm > /dev/null 2>&1; then
    npm install -g prettier javascript-typescript-langserver
  fi

  if command -v python > /dev/null 2>&1; then
    pip install --user python-language-server pycodestyle
  fi
}

main "${@:-}"
