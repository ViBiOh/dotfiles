#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

readonly OP_BROKER_SOCKET_DIR="${HOME}/.local/state/op_broker"

symlink() {
  symlink_home ".local/bin/op_broker"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink

  rm -rf "${OP_BROKER_SOCKET_DIR}"
}

install() {
  mkdir -p "${OP_BROKER_SOCKET_DIR}"
  chmod 700 "${OP_BROKER_SOCKET_DIR}"

  if ! [[ ${OSTYPE} =~ ^darwin ]]; then
    return
  fi

  symlink

  packages_install "socat"

  mkdir -p "${HOME}/.config/op_broker"
}
