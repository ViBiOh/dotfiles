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
  symlink_home ".ssh/config"

  if command -v op >/dev/null 2>&1; then
    symlink_home ".ssh/config.d/op"
  fi

  ssh-keyscan "github.com" >"${HOME}/.ssh/known_hosts"
  ssh-keyscan "gitlab.com" >>"${HOME}/.ssh/known_hosts"
  ssh-keyscan "codeberg.org" >>"${HOME}/.ssh/known_hosts"
}

credentials() {
  if ! command -v pass >/dev/null 2>&1 || ! [[ -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]]; then
    return
  fi

  extract_secret "infra/ssh" ".ssh/config.d/infra"
}
