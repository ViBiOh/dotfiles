#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".gnupg/gpg.conf"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink

  if command -v gpgconf >/dev/null 2>&1; then
    gpgconf --kill gpg-agent
  fi
}

install() {
  packages_install "gnupg" "hopenpgp-tools" "ykman"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "pinentry-mac"
  fi

  if ! command -v gpg >/dev/null 2>&1; then
    return
  fi

  mkdir -p "${HOME}/.gnupg"
  chmod 700 "${HOME}/.gnupg"

  echo "enable-ssh-support
default-cache-ttl 3600
max-cache-ttl 3600
pinentry-program ${BREW_PREFIX}/bin/pinentry-mac" >"${HOME}/.gnupg/gpg-agent.conf"
}

credentials() {
  local KEY_ID="DD539006C49CAB71"

  if ! gpg --list-keys "${KEY_ID}"; then
    gpg --receive-keys --keyserver "hkps://keys.openpgp.org" "${KEY_ID}"
  fi
}
