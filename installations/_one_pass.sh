#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

script_dir() {
  local FILE_SOURCE="${BASH_SOURCE[0]}"

  if [[ -L ${FILE_SOURCE} ]]; then
    dirname "$(readlink "${FILE_SOURCE}")"
  else
    (
      cd "$(dirname "${FILE_SOURCE}")" && pwd
    )
  fi
}

install() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "1password-cli"
  fi

  if command -v op >/dev/null 2>&1; then
    op completion bash >"$(script_dir)/../sources/op-completion.sh"
  fi
}
