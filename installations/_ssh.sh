#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if command -v ssh_agent_stop >/dev/null 2>&1; then
    set +e
    ssh_agent_stop
    set -e
  fi

  rm -rf "${HOME}/.ssh"
}

install() {
  local EXTRA_CONFIG=""

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    EXTRA_CONFIG="
  UseKeyChain no"

    if command -v op >/dev/null 2>&1; then
      EXTRA_CONFIG+='
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'
    fi
  fi

  mkdir -p "${HOME}/.ssh"

  echo "Host *
  PasswordAuthentication no
  ChallengeResponseAuthentication no
  HashKnownHosts yes${EXTRA_CONFIG}
  ServerAliveInterval 300
  ServerAliveCountMax 2" >"${HOME}/.ssh/config"

  ssh-keyscan "github.com" >"${HOME}/.ssh/known_hosts"
  ssh-keyscan "gitlab.com" >>"${HOME}/.ssh/known_hosts"
  ssh-keyscan "codeberg.org" >>"${HOME}/.ssh/known_hosts"
}

credentials() {
  if ! command -v pass >/dev/null 2>&1 || ! [[ -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]]; then
    return
  fi

  extract_secret "infra/ssh" ".ssh/config"
}
