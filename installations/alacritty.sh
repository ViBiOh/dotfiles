#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".alacritty.toml"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    # renovate: datasource=github-releases depName=alacritty/alacritty
    local ALACRITTY_VERSION="v0.17.0"

    dmg_to_app "https://github.com/alacritty/alacritty/releases/download/${ALACRITTY_VERSION}/Alacritty-${ALACRITTY_VERSION}.dmg"
  elif package_exists "alacritty"; then
    packages_install_desktop "alacritty"
  fi
}
