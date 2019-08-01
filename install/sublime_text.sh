#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if [[ "${OSTYPE}" =~ ^darwin ]] && [[ -f "/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl" ]]; then
    ln -s "/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl" "${HOME}/opt/bin/subl"
  fi

  if command -v subl > /dev/null 2>&1; then
    pushd "$(git rev-parse --show-toplevel)/sublime"
    ./install.sh
    popd
  fi
}
