#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    brew install git
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq git
  elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed git
  fi

  if ! command -v git > /dev/null 2>&1; then
    return
  fi

  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  curl -q -sS -Lo "${SCRIPT_DIR}/../sources/git-prompt" "https://raw.githubusercontent.com/git/git/v$(git --version | awk '{print $3}')/contrib/completion/git-prompt.sh"

  if command -v perl > /dev/null 2>&1; then
    curl -q -sS -Lo "${HOME}/opt/bin/diff-so-fancy" "https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy"
    chmod +x "${HOME}/opt/bin/diff-so-fancy"
  fi
}
