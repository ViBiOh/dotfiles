#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if ! command -v git > /dev/null 2>&1; then
    echo "git not found"
    exit
  fi

  if ! command -v make > /dev/null 2>&1; then
    echo "make not found"
    exit
  fi

  if command -v brew > /dev/null 2>&1; then
    brew install gnu-getopt tree oath-toolkit
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq tree
  fi

  rm -rf "${HOME}/password-store"
  git clone --depth 1 https://git.zx2c4.com/password-store "${HOME}/password-store"
  pushd "${HOME}/password-store"
  WITH_BASHCOMP=no WITH_ZSHCOMP=no WITH_FISHCOMP=no PREFIX="${HOME}/opt" make install
  popd
  rm -rf "${HOME}/password-store"

  rm -rf "${HOME}/pass-otp"
  git clone --depth 1 https://github.com/tadfisher/pass-otp "${HOME}/pass-otp"
  pushd "${HOME}/pass-otp"
  PREFIX="${HOME}/opt" BASHCOMPDIR=${HOME}/opt/bash_completion.d make install
  popd
  rm -rf "${HOME}/pass-otp"
}

main
