#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  local TERRAFORM_VERSION=0.12.3
  local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  local ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

  if [[ "${ARCH}" = "x86_64" ]]; then
    ARCH="amd64"
  elif [[ "${ARCH}" =~ ^armv.l$ ]]; then
    ARCH="armv6l"
  fi

  local TERRAFORM_ARCHIVE="terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"

  curl -O "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ARCHIVE}"
  unzip -d "${HOME}/opt/bin" "${TERRAFORM_ARCHIVE}"
  rm -rf "${TERRAFORM_ARCHIVE}"
}

main
