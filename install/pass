#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if command -v brew >/dev/null 2>&1; then
    brew install pass pass-otp
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y -qq --no-install-recommends pass pass-extension-otp
  fi

  if ! command -v pass >/dev/null 2>&1; then
    return
  fi

  if [[ ! -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]]; then
    return
  fi

  pass git pull
}
