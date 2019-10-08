#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if command -v brew > /dev/null 2>&1; then
    brew cask reinstall sublime-text
    ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" "${HOME}/opt/bin/subl"
  fi

  if command -v subl > /dev/null 2>&1; then
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    pushd "${SCRIPT_DIR}/../sublime"
    ./install.sh
    popd
  fi
}
