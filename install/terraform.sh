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
  unzip -o -d "${HOME}/opt/bin" "${TERRAFORM_ARCHIVE}"
  rm -rf "${TERRAFORM_ARCHIVE}"

  if ! command -v pass > /dev/null 2>&1; then
    exit
  fi

  local PASS_DIR=${PASSWORD_STORE_DIR-~/.password-store}
  local TERRAFORM_PASS=$(find "${PASS_DIR}" -name '*terraform.gpg' -print | sed -e "s|${PASS_DIR}/\(.*\)\.gpg$|\1|")

  if [[ $(echo "${TERRAFORM_PASS}" | wc -l) -eq 1 ]]; then
    local TERRAFORM_TOKEN=$(pass show "${TERRAFORM_PASS}" | grep token | awk '{print $2}')

    echo "credentials \"app.terraform.io\" {
  token = \"${TERRAFORM_TOKEN}\"
}" > "${HOME}/.terraformrc"
  fi
}

main
