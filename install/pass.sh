#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if ! command -v git > /dev/null 2>&1; then
    echo "git is required"
    exit
  fi

  if ! command -v make > /dev/null 2>&1; then
    echo "make is required"
    exit
  fi

  if command -v brew > /dev/null 2>&1; then
    brew install gnu-getopt tree oath-toolkit zbar
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq tree
  fi

  rm -rf "${HOME}/password-store"
  git clone --depth 1 "https://git.zx2c4.com/password-store" "${HOME}/password-store"
  pushd "${HOME}/password-store"
  WITH_BASHCOMP=no WITH_ZSHCOMP=no WITH_FISHCOMP=no PREFIX="${HOME}/opt" make install
  popd
  rm -rf "${HOME}/password-store"

  rm -rf "${HOME}/pass-otp"
  git clone --depth 1 "https://github.com/tadfisher/pass-otp" "${HOME}/pass-otp"
  pushd "${HOME}/pass-otp"
  PREFIX="${HOME}/opt" BASHCOMPDIR=${HOME}/opt/bash_completion.d make install
  popd
  rm -rf "${HOME}/pass-otp"

  if ! command -v pass > /dev/null 2>&1; then
    return
  fi

  local PASS_DIR=${PASSWORD_STORE_DIR-${HOME}/.password-store}
  if [[ ! -d "${PASS_DIR}" ]]; then
    return
  fi

  pass git pull
}
