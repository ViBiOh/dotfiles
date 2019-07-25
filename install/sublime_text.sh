#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if command -v brew > /dev/null 2>&1; then
    brew cask reinstall sublime-text
  elif command -v pacman > /dev/null 2>&1; then
    if [[ $(cat "/etc/pacman.conf" | grep "sublime-text" | wc -l) -eq 0 ]]; then
      local SUBLIME_TEXT_SIGN_KEY="8A8F901A"
      local SUBLIME_TEXT_KEY_FILE="sublimehq-pub.gpg"

      curl -O "https://download.sublimetext.com/${SUBLIME_TEXT_KEY_FILE}"
      sudo pacman-key --add "${SUBLIME_TEXT_KEY_FILE}"
      sudo pacman-key --lsign-key "${SUBLIME_TEXT_SIGN_KEY}"
      rm "${SUBLIME_TEXT_KEY_FILE}"

      echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a "/etc/pacman.conf"

      sudo pacman -Syuq --noconfirm
    fi

    sudo pacman -S --noconfirm --needed sublime-text
  fi

  if command -v subl > /dev/null 2>&1; then
    pushd "$(git rev-parse --show-toplevel)/sublime"
    ./install.sh
    popd
  fi
}

main
