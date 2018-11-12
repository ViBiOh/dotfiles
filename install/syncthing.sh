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
elif [[ "${ARCH}" =~ ^arm ]]; then
  ARCH="arm"
fi

if [ "${OS}" == "Darwin" ]; then
  OS="macos"
fi

SYNCTHING_FILE="syncthing-${OS,,}-${ARCH,,}-${SYNCTHING_VERSION}"

curl -o "${HOME}/opt/${SYNCTHING_FILE}.tar.gz" "https://github.com/syncthing/syncthing/releases/download/${SYNCTHING_VERSION}/${SYNCTHING_FILE}.tar.gz"
tar -C "${HOME}/opt" -xzf "${HOME}/opt/${SYNCTHING_FILE}.tar.gz"
cp "${HOME}/opt/${SYNCTHING_FILE}/syncthing" "${HOME}/opt/bin/syncthing"

if [ `uname -s` == "Linux" ]; then
  cat "${HOME}/opt/${SYNCTHING_FILE}/etc/linux-systemd/system/syncthing@.service" | sed -e "s|/usr/bin/syncthing|${HOME}/opt/bin/syncthing|g" | sudo tee "/etc/systemd/system/syncthing@.service" > /dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable syncthing@`whoami`.service
  sudo systemctl start syncthing@`whoami`.service
fi

rm -rf "${HOME}/opt/${SYNCTHING_FILE}"*
