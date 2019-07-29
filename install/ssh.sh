#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  stop_ssh_agent

  rm -rf "${HOME}/.ssh/environment"
  rm -rf "${HOME}/.ssh/known_hosts"
}

main() {
  clean

  local EXTRA_CONFIG=""

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    EXTRA_CONFIG="
  UseKeyChain no"
  fi

  mkdir -p "${HOME}/.ssh"

  echo "Host *
  PasswordAuthentication no
  ChallengeResponseAuthentication no
  ForwardAgent yes
  HashKnownHosts yes${EXTRA_CONFIG}
  ServerAliveInterval 300
  ServerAliveCountMax 2
" > "${HOME}/.ssh/config"

  find "${HOME}/.ssh/" -name "config_*" -type f -exec cat {} + >> "${HOME}/.ssh/config"
}

main
