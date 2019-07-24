#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if command -v pacman > /dev/null 2>&1; then
    local SUBLIME_TEXT_SIGN_KEY="8A8F901A"
    local SUBLIME_TEXT_KEY_FILE="sublimehq-pub.gpg"

    curl -O "https://download.sublimetext.com/${SUBLIME_TEXT_KEY_FILE}"
    sudo pacman-key --add "${SUBLIME_TEXT_KEY_FILE}"
    sudo pacman-key --lsign-key "${SUBLIME_TEXT_SIGN_KEY}"
    rm "${SUBLIME_TEXT_KEY_FILE}"

    echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/dev/x86_64" | sudo tee -a /etc/pacman.conf

    sudo pacman -Syu sublime-text
  fi
}

main
