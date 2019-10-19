#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if command -v brew > /dev/null 2>&1; then
    brew install pass pass-otp
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq pass pass-extension-otp
  elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed pass pass-otp
  fi

  if ! command -v pass > /dev/null 2>&1; then
    return
  fi

  local PASS_DIR=${PASSWORD_STORE_DIR-${HOME}/.password-store}
  if [[ ! -d "${PASS_DIR}" ]]; then
    return
  fi

  pass git pull
}
