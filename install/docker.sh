#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if command -v docker > /dev/null 2>&1; then
    docker system prune -f

    docker rmi $(docker images -q) || true
    docker network rm $(docker network ls -q) || true
    docker volume rm $(docker volume ls -q) || true
  fi
}

main() {
  clean

  if ! command -v docker > /dev/null 2>&1; then
    return
  fi

  local CTOP_VERSION="0.7.2"
  local OS="$(uname -s | tr "[:upper:]" "[:lower:]")"
  local ARCH="$(uname -m | tr "[:upper:]" "[:lower:]")"

  if [[ "${ARCH}" = "x86_64" ]]; then
    ARCH="amd64"
  fi

  curl -Lo "${HOME}/opt/bin/ctop" "https://github.com/bcicen/ctop/releases/download/v${CTOP_VERSION}/ctop-${CTOP_VERSION}-${OS}-${ARCH}"
  chmod +x "${HOME}/opt/bin/ctop"
}

main
