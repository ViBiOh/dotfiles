#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  # renovate: datasource=github-releases depName=syncthing/syncthing
  local SYNCTHING_VERSION="v1.30.0"

  local SYNCTHING_RELEASE
  SYNCTHING_RELEASE="syncthing-$(normalized_os "macos")-$(normalized_arch "amd64" "arm" "arm64")-${SYNCTHING_VERSION}"

  local SYNCTHING_ARCHIVE_TYPE="tar.gz"
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    SYNCTHING_ARCHIVE_TYPE="zip"
  fi

  archive_to_binary "https://github.com/syncthing/syncthing/releases/download/${SYNCTHING_VERSION}/${SYNCTHING_RELEASE}.${SYNCTHING_ARCHIVE_TYPE}" "${SYNCTHING_RELEASE}/syncthing"
}
