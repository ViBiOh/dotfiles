#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.config/rclone/"
}

install() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "rclone"
  fi
}

credentials() {
  if ! command -v pass >/dev/null 2>&1 || ! [[ -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]]; then
    return
  fi

  extract_secret "infra/rclone-config" ".config/rclone/rclone"
}
