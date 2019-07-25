#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
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

  if command -v pacman > /dev/null 2>&1; then
    local GIT_COMPLETION="git-prompt.sh"

    curl -O  "https://raw.githubusercontent.com/git/git/v$(git --version | awk '{print $3}')/contrib/completion/${GIT_COMPLETION}"
    sudo mv "${GIT_COMPLETION}" "/usr/share/bash-completion/completions/git"
  fi

  if command -v perl > /dev/null 2>&1; then
    curl -o "${HOME}/opt/bin/diff-so-fancy" "https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy"
    chmod +x "${HOME}/opt/bin/diff-so-fancy"
  fi
}

main
