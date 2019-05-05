#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  local MAC_OS_SSH_CONFIG=""

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    MAC_OS_SSH_CONFIG="
  UseKeyChain no"
  fi

  echo "Host *
  PasswordAuthentication no
  ChallengeResponseAuthentication no
  ForwardAgent yes
  HashKnownHosts yes${MAC_OS_SSH_CONFIG}
  ServerAliveInterval 300
  ServerAliveCountMax 2
" > "${HOME}/.ssh/config"

  find "${HOME}/.ssh/" -name "config_*" -type f -exec cat {} + >> "${HOME}/.ssh/config"
}

main
