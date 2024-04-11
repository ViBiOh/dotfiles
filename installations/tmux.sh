#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  packages_install "tmux"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "reattach-to-user-namespace" "pam-reattach"

    echo "auth       optional       /opt/homebrew/lib/pam/pam_reattach.so
auth       sufficient     pam_tid.so" | sudo tee "/etc/pam.d/sudo_local" >/dev/null
  fi
}
