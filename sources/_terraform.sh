#!/usr/bin/env bash

terraform_install() {
  local TERRAFORM_VERSION=${1}
  shift

  local TERRAFORM_PATH="${HOME}/opt/bin/terraform"
  local TERRAFORM_VERSION_PATH="${HOME}/opt/bin/terraform_${TERRAFORM_VERSION#v}"

  if ! [[ -e "${HOME}/opt/bin/terraform_${TERRAFORM_VERSION#v}" ]]; then
    archive_to_binary "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION#v}/terraform_${TERRAFORM_VERSION#v}_$(normalized_os)_$(normalized_arch "amd64" "arm" "arm64").zip" "terraform" "${TERRAFORM_VERSION_PATH}"
  fi

  rm -f "${TERRAFORM_PATH}"
  ln -s "${TERRAFORM_VERSION_PATH}" "${TERRAFORM_PATH}"
}

if command -v terraform >/dev/null 2>&1; then
  complete -C "${HOME}/opt/bin/terraform" terraform

  __terraform_ps1() {
    # preserve exit status
    local exit="${?}"

    if [[ $(find . -maxdepth 1 -type f -name "*.tf" | wc -l) -gt 0 ]]; then
      printf " 🔧 %s" "$(terraform workspace show)"
    fi

    return "${exit}"
  }
fi
