#!/usr/bin/env bash

packages_update() {
  if command -v brew >/dev/null 2>&1; then
    brew update
    brew upgrade
  elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get dist-upgrade -qq
    sudo apt-get upgrade -qq
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman --sync --sysupgrade --refresh --quiet --noconfirm
  fi
}

packages_install_desktop() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install --cask "${@}"
  else
    packages_install "${@}"
  fi
}

packages_install() {
  if command -v brew >/dev/null 2>&1; then
    brew install "${@}"
  elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    export RUNLEVEL=1
    sudo apt-get install -qq --no-install-recommends "${@}"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman --sync --noconfirm --needed "${@}"
  fi
}

package_exists() {
  if command -v brew >/dev/null 2>&1; then
    if [[ $(brew search "/^${1}$/" | wc -l) -eq 0 ]]; then
      return 1
    fi
  elif command -v apt-cache >/dev/null 2>&1; then
    if [[ $(apt-cache search "^${1}$" | wc -l) -eq 0 ]]; then
      return 1
    fi
  elif command -v pacman >/dev/null 2>&1; then
    if [[ $(pacman --sync --search "^${1}$" | wc -l) -eq 0 ]]; then
      return 1
    fi
  fi

  return 0
}

packages_clean() {
  if command -v brew >/dev/null 2>&1; then
    brew cleanup -s
  elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get autoremove --yes
    sudo apt-get clean all
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman --sync --clean --quiet --noconfirm
  fi
}
