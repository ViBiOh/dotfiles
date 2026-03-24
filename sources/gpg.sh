#!/usr/bin/env bash

GPG_TTY="$(tty)"
export GPG_TTY

if ! command -v gpgconf >/dev/null 2>&1; then
  return
fi

if [[ -z ${SSH_AUTH_SOCK:-} ]]; then
  SSH_AUTH_SOCK="$(gpgconf --list-dirs "agent-ssh-socket")"
  export SSH_AUTH_SOCK
fi

gpg_agent_start() {
  if [[ $(pgrep gpg-agent | wc -l) -eq 1 ]]; then
    return 0
  fi

  gpgconf --launch gpg-agent
  gpg-connect-agent updatestartuptty /bye >/dev/null
}

gpg_agent_stop() {
  gpgconf --kill gpg-agent
}

if [[ -d ${HOME}/.gnupg ]]; then
  gpg_agent_start
fi

gpg_eject_card() {
  gpg-connect-agent "scd serialno" "learn --force" /bye
}
