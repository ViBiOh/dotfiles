#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  local SYNCTHING_VERSION=1.3.0

  local OS="$(uname -s | tr "[:upper:]" "[:lower:]")"
  local ARCH="$(uname -m | tr "[:upper:]" "[:lower:]")"

  if [[ "${OS}" = "darwin" ]]; then
    OS="macos"
  fi

  if [[ "${ARCH}" = "x86_64" ]]; then
    ARCH="amd64"
  fi

  local SYNCTHING_ARCHIVE="syncthing-${OS}-${ARCH}-v${SYNCTHING_VERSION}"

  curl -q -sS -LO "https://github.com/syncthing/syncthing/releases/download/v${SYNCTHING_VERSION}/${SYNCTHING_ARCHIVE}.tar.gz"

  tar -xzf "${SYNCTHING_ARCHIVE}.tar.gz"
  cp "${SYNCTHING_ARCHIVE}/syncthing" "${HOME}/opt/bin/"
  rm -rf "${SYNCTHING_ARCHIVE}" "${SYNCTHING_ARCHIVE}.tar.gz"
}
