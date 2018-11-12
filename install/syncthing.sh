#!/usr/bin/env bash

set -e
set -u

echo "-------------"
echo "- syncthing -"
echo "-------------"

SYNCTHING_VERSION=v0.14.52
OS=`uname -s`
ARCH=`uname -m`

if [ "${ARCH}" == "x86_64" ]; then
  ARCH="amd64"
fi

if [ "${OS}" == "Darwin" ]; then
  OS="macos"
fi

SYNCTHING_ARCHIVE="syncthing-${OS,,}-${ARCH,,}-${SYNCTHING_VERSION}.tar.gz"

curl -O "https://github.com/syncthing/syncthing/releases/download/${SYNCTHING_VERSION}/${SYNCTHING_ARCHIVE}"
rm -rf "${HOME}/opt/syncthing"
tar -C "${HOME}/opt" -xzf "${SYNCTHING_ARCHIVE}"
rm -rf "${SYNCTHING_ARCHIVE}"
