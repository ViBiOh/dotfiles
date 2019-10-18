#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.terraform"*
}

credentials() {
  if ! command -v pass > /dev/null 2>&1; then
    exit
  fi

  local PASS_DIR="${PASSWORD_STORE_DIR-${HOME}/.password-store}"
  local TERRAFORM_PASS
  TERRAFORM_PASS="$(find "${PASS_DIR}" -name "*terraform.gpg" -print | sed -e "s|${PASS_DIR}/\(.*\)\.gpg$|\1|")"

  if [[ "$(echo "${TERRAFORM_PASS}" | wc -l)" -eq 1 ]]; then
    local TERRAFORM_TOKEN
    TERRAFORM_TOKEN="$(pass show "${TERRAFORM_PASS}" | grep token | awk '{print $2}')"

    echo "credentials \"app.terraform.io\" {
  token = \"${TERRAFORM_TOKEN}\"
}" > "${HOME}/.terraformrc"
  fi
}

install() {
  local TERRAFORM_VERSION="0.12.11"

  local OS
  OS="$(uname -s | tr "[:upper:]" "[:lower:]")"
  local ARCH
  ARCH="$(uname -m | tr "[:upper:]" "[:lower:]")"

  if [[ "${ARCH}" = "x86_64" ]]; then
    ARCH="amd64"
  elif [[ "${ARCH}" =~ ^armv.l$ ]]; then
    ARCH="arm"
  fi

  local TERRAFORM_ARCHIVE="terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"

  curl -q -sS -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ARCHIVE}"
  unzip -o -d "${HOME}/opt/bin" "${TERRAFORM_ARCHIVE}"
  rm -rf "${TERRAFORM_ARCHIVE}"

  curl -q -sS -L "https://raw.githubusercontent.com/MeilleursAgents/terraform-provider-ansiblevault/master/install.sh" | bash
}
