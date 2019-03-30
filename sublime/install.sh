#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  echo Configuring SublimeText

  local GO_PLUGIN="SublimeGo"
  local PKG="${HOME}/Library/Application Support/Sublime Text 3/Packages"
  local PKG_USER="${PKG}/User"

  mkdir -p "${PKG_USER}"
  rm -rf "${PKG_USER}"/* "${PKG}/${GO_PLUGIN}"

  cp -r "${SCRIPT_DIR}/${GO_PLUGIN}" "${PKG}/${GO_PLUGIN}"
  cp "${SCRIPT_DIR}/snippets/"* "${PKG_USER}/"
  cp "${SCRIPT_DIR}/settings/"* "${PKG_USER}/"

  if command -v go > /dev/null 2>&1; then
    go get -u github.com/mdempsky/gocode
    go get -u github.com/sourcegraph/go-langserver
    go get -u golang.org/x/tools/cmd/gotype
  fi

  if command -v npm > /dev/null 2>&1; then
    npm install -g prettier javascript-typescript-langserver
  fi

  echo Success!
}

main
