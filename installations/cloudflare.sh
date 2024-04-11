#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.cloudflared"
}

install() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    brew install "cloudflared"
  fi
}
