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
  if pgrep -x gpg-agent >/dev/null; then
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

gpg_temp() {
  export GNUPGHOME
  GNUPGHOME=$(mktemp -d "${TMPDIR:-/tmp}/$(date +%Y.%m.%d)-XXXXXXXX")
  printf "\nTemporary directory:\t%s\n\n" "$GNUPGHOME"

  curl https://raw.githubusercontent.com/drduh/YubiKey-Guide/main/config/gpg.conf --output "${GNUPGHOME}/gpg.conf"
}

gpg_temp_clean() {
  if var_confirm "Delete ${GNUPGHOME}"; then
    rm -rf "${GNUPGHOME}"
    unset GNUPGHOME
  fi
}
