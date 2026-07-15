#!/usr/bin/env bash

random() {
  openssl rand -hex "${1:-31}"
}

openssl_cipher() {
  local PASSPHRASE="${1:-}"
  var_read PASSPHRASE "" "secret"

  openssl aes-256-cbc -e -pbkdf2 -base64 -pass fd:3 3< <(printf -- '%s' "${PASSPHRASE}")
}

openssl_decipher() {
  local PASSPHRASE="${1:-}"
  var_read PASSPHRASE "" "secret"

  openssl aes-256-cbc -d -pbkdf2 -base64 -pass fd:3 3< <(printf -- '%s' "${PASSPHRASE}")
}
