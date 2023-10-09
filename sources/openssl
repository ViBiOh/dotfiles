#!/usr/bin/env bash

random() {
  openssl rand -hex "${1:-31}"
}

openssl_cipher() {
  if [[ ${#} -lt 1 ]]; then
    printf "%bUsage: openssl_cipher PASSPHRASE%b\n" "${RED}" "${RESET}" 1>&2
    return 1
  fi

  local PASSPHRASE="${1}"
  shift

  openssl aes-256-cbc -e -k "${PASSPHRASE}" -pbkdf2 -base64
}

openssl_decipher() {
  if [[ ${#} -lt 1 ]]; then
    printf "%bUsage: openssl_decipher PASSPHRASE%b\n" "${RED}" "${RESET}" 1>&2
    return 1
  fi

  local PASSPHRASE="${1}"
  shift

  openssl aes-256-cbc -d -k "${PASSPHRASE}" -pbkdf2 -base64
}
