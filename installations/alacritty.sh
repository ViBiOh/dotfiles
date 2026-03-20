#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if package_exists "alacritty"; then
    packages_install_desktop "alacritty"
  fi
}
