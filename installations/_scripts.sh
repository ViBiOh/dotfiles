#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${DOTFILES_DIR}/scripts"
}

install() {
  (
    cd "${DOTFILES_DIR}/"
    curl --disable --silent --show-error --location --max-time 30 "https://raw.githubusercontent.com/ViBiOh/scripts/main/bootstrap.sh" | bash -s -- "-c" \
      "github" \
      "http" \
      "rotate.sh" \
      "ssh" \
      "var" \
      "version"
  )

  source "${DOTFILES_DIR}/scripts/meta" && meta_check "var"
}
