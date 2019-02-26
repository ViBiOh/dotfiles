#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  local CTOP_VERSION='0.7.2'
  local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  local ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

  if [[ "${ARCH}" = "x86_64" ]]; then
    ARCH="amd64"
  fi

  if command -v go > /dev/null 2>&1; then
    curl -Lo "${HOME}/opt/bin/ctop" "https://github.com/bcicen/ctop/releases/download/v${CTOP_VERSION}/ctop-${CTOP_VERSION}-${OS}-${ARCH}"
    chmod +x "${HOME}/opt/bin/ctop"
  fi
}

main
