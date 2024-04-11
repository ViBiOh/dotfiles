#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.fzf.bash"
}

install() {
  packages_install "fzf"

  "${BREW_PREFIX}/opt/fzf/install" --key-bindings --completion --no-zsh --no-fish --no-update-rc
}
