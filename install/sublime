#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if command -v brew > /dev/null 2>&1; then
    brew cask reinstall sublime-text sublime-merge
    ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" "${HOME}/opt/bin/subl"
  elif command -v pacman > /dev/null 2>&1; then
    if [[ $(grep -c "sublime-text" "/etc/pacman.conf") -eq 0 ]]; then
      local SUBLIME_TEXT_SIGN_KEY="8A8F901A"
      local SUBLIME_TEXT_KEY_FILE="sublimehq-pub.gpg"

      curl -q -sSL --max-time 30 -O "https://download.sublimetext.com/${SUBLIME_TEXT_KEY_FILE}"
      sudo pacman-key --add "${SUBLIME_TEXT_KEY_FILE}"
      sudo pacman-key --lsign-key "${SUBLIME_TEXT_SIGN_KEY}"
      rm "${SUBLIME_TEXT_KEY_FILE}"

      echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a "/etc/pacman.conf"

      sudo pacman -Syuq --noconfirm
    fi

    sudo pacman -S --noconfirm --needed sublime-text sublime-merge
  fi

  if command -v subl > /dev/null 2>&1; then
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    "${SCRIPT_DIR}/../sublime/init"
  fi
}
