#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "1password-cli"
  fi

  if command -v op >/dev/null 2>&1; then
    op completion bash >"${HOME}/opt/completions/op-completion.sh"
  fi
}
