#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.config/ghostty/"
}

install() {
  if package_exists "ghostty"; then
    packages_install_desktop "ghostty"
  fi

  mkdir -p "${HOME}/.config/ghostty"

  echo 'scrollback-limit = 10000000

background = "#000000"

macos-titlebar-style = "hidden"
macos-auto-secure-input = true

quit-after-last-window-closed = true

font-size = 13
font-feature = "-calt"
' >"${HOME}/.config/ghostty/config"
}
