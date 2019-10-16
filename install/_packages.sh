#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if ! command -v brew > /dev/null 2>&1; then
      mkdir "${HOME}/homebrew" && curl -q -sS -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "${HOME}/homebrew"
      source "${SCRIPT_DIR}/../sources/_homebrew"
    fi

    brew update
    brew upgrade
    brew install \
      bash \
      bash-completion \
      htop \
      openssl \
      curl \
      fswatch

    if [[ "$(grep -c "$(brew --prefix)" "/etc/shells")" -eq 0 ]]; then
      echo "+-------------------------+"
      echo "| changing shell for user |"
      echo "+-------------------------+"

      echo "$(brew --prefix)/bin/bash" | sudo tee -a "/etc/shells" > /dev/null
      chsh -s "$(brew --prefix)/bin/bash" -u "$(whoami)"
    fi

    if [[ ! -f "${HOME}/.bash_profile" ]]; then
      echo "+---------------------------------+"
      echo "| adding .bashrc to .bash_profile |"
      echo "+---------------------------------+"

      echo '#!/usr/bin/env bash

if [[ -f "${HOME}/.bashrc" ]]; then
  source "${HOME}/.bashrc"
fi' > "${HOME}/.bash_profile"
    fi
  elif command -v apt-get > /dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive

    sudo apt-get update
    sudo apt-get dist-upgrade -y -qq
    sudo apt-get upgrade -y -qq
    sudo apt-get install -y -qq apt-transport-https

    sudo apt-get install -y -qq \
      bash \
      bash-completion \
      htop \
      openssl \
      curl \
      vim
  elif command -v pacman > /dev/null 2>&1; then
    # Enabling fn key as f1..f12 instead of media on macbook keyboard
    if [[ "$(grep -c "hid_apple" /etc/modprobe.d/hid_apple.conf)" -eq 0 ]]; then
      echo options hid_apple fnmode=2 | sudo tee -a /etc/modprobe.d/hid_apple.conf
    fi

    sudo pacman -Syuq --noconfirm
    sudo pacman -S --noconfirm --needed \
      make \
      gcc \
      binutils \
      bash \
      bash-completion \
      htop \
      openssl \
      curl \
      vim
  fi
}
