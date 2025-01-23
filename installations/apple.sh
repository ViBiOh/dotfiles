#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install_desktop "rectangle" "qwerty-fr"

    packages_install "pam-reattach"

    echo "auth       optional       ${BREW_PREFIX}/lib/pam/pam_reattach.so
auth       sufficient     pam_tid.so" | sudo tee "/etc/pam.d/sudo_local" >/dev/null
  fi
}
