#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.terraform"*
}

install() {
  # renovate: datasource=github-releases depName=hashicorp/terraform
  local TERRAFORM_VERSION="v1.12.2"

  terraform_install "${TERRAFORM_VERSION}"

  mkdir -p "${HOME}/.terraform.d/plugin-cache"
  printf -- "plugin_cache_dir = \"%s/.terraform.d/plugin-cache\"\ndisable_checkpoint = true\n" "${HOME}" >"${HOME}/.terraformrc"

  # renovate: datasource=github-releases depName=hashicorp/terraform-ls
  local TERRAFORM_LS_VERSION="v0.36.5"
  archive_to_binary "https://releases.hashicorp.com/terraform-ls/${TERRAFORM_LS_VERSION#v}/terraform-ls_${TERRAFORM_LS_VERSION#v}_$(normalized_os)_$(normalized_arch "amd64" "arm" "arm64").zip" "terraform-ls"
}

credentials() {
  if command -v pass >/dev/null 2>&1 && [[ -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]] && [[ $(pass find terraform | wc -l) -gt 1 ]]; then
    printf -- "credentials \"app.terraform.io\" {\n  token = \"%s\"\n}" "$(pass_get "dev/terraform" "token")" >>"${HOME}/.terraformrc"
    chmod 600 "${HOME}/.terraformrc"
  fi
}
