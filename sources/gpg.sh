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

cipher_for() {
  if [[ ${#} -lt 1 ]]; then
    printf -- "%bUsage: cipher_for GITHUB_USERNAME%b\n" "${RED}" "${RESET}" 1>&2
    return 1
  fi

  local GITHUB_USERNAME="${1}"
  shift 1

  local TEMP_GNUPGHOME
  TEMP_GNUPGHOME="$(mktemp -d)"

  cp "${GNUPGHOME:-${HOME}/.gnupg/gpg.conf}" "${TEMP_GNUPGHOME}/gpg.conf"

  local PUBLIC_KEY
  PUBLIC_KEY="$(mktemp)"

  curl --disable --silent --show-error --location --max-time 10 "https://github.com/${GITHUB_USERNAME}.gpg" >"${PUBLIC_KEY}"
  gpg --homedir "${TEMP_GNUPGHOME}" --import "${PUBLIC_KEY}"

  local ENCRYPT_KEY_IDS
  ENCRYPT_KEY_IDS="$(gpg --homedir "${TEMP_GNUPGHOME}" --list-keys --with-colons | grep pub | awk -F: '{print "{\"id\":\"" $5 "\",\"cap\":\"" $12 "\"}"}' | jq --raw-output 'select(.cap | test("e|E")) | .id')"

  if [[ -z ${ENCRYPT_KEY_IDS} ]]; then
    printf -- "%bno encryption key found%b\n" "${RED}" "${RESET}" 1>&2
  else
    local EMAILS

    for keyID in ${ENCRYPT_KEY_IDS}; do
      EMAILS+="$(gpg --homedir "${TEMP_GNUPGHOME}" --list-keys --with-colons "${keyID}" | grep uid | awk -F: '{print $10}')"
      EMAILS+=$'\n'
    done

    local RECIPIENT
    RECIPIENT="$(printf -- "%s" "${EMAILS}" | uniq | fzf --prompt "Email: ")"

    gpg --homedir "${TEMP_GNUPGHOME}" --encrypt --recipient "${RECIPIENT}" "${@}" | base64

    printf -- "%bDecipher with: base64 -D | gpg --decrypt%b\n" "${YELLOW}" "${RESET}" 1>&2
  fi

  rm -rf "${TEMP_GNUPGHOME}" "${PUBLIC_KEY}"
}

decipher_from() {
  if [[ ${#} -lt 1 ]]; then
    printf -- "%bUsage: decipher_from GITHUB_USERNAME%b\n" "${RED}" "${RESET}" 1>&2
    return 1
  fi

  local GITHUB_USERNAME="${1}"
  shift 1

  local TEMP_GNUPGHOME
  TEMP_GNUPGHOME="$(mktemp -d)"

  cp "${GNUPGHOME:-${HOME}/.gnupg/gpg.conf}" "${TEMP_GNUPGHOME}/gpg.conf"

  local PUBLIC_KEY
  PUBLIC_KEY="$(mktemp)"

  curl --disable --silent --show-error --location --max-time 10 "https://github.com/${GITHUB_USERNAME}.gpg" >"${PUBLIC_KEY}"
  gpg --homedir "${TEMP_GNUPGHOME}" --import "${PUBLIC_KEY}"
  gpg --homedir "${TEMP_GNUPGHOME}" --decrypt "${@}"

  rm -rf "${TEMP_GNUPGHOME}" "${PUBLIC_KEY}"
}
