#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.terraform"*
}

install() {
  # renovate: datasource=github-releases depName=hashicorp/terraform
  local TERRAFORM_VERSION="v1.14.6"

  terraform_install "${TERRAFORM_VERSION}"

  mkdir -p "${HOME}/.terraform.d/plugin-cache"
  printf -- "plugin_cache_dir = \"%s/.terraform.d/plugin-cache\"\ndisable_checkpoint = true\n" "${HOME}" >"${HOME}/.terraformrc"

  # renovate: datasource=github-releases depName=hashicorp/terraform-ls
  local TERRAFORM_LS_VERSION="v0.38.4"
  archive_to_binary "https://releases.hashicorp.com/terraform-ls/${TERRAFORM_LS_VERSION#v}/terraform-ls_${TERRAFORM_LS_VERSION#v}_$(normalized_os)_$(normalized_arch "amd64" "arm" "arm64").zip" "terraform-ls"
}
