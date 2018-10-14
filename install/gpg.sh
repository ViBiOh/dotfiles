#!/usr/bin/env bash

set -e
set -u

echo "-------"
echo "- GPG -"
echo "-------"

if [ `uname` == 'Darwin' ]; then
  brew install gnupg
elif command -v apt-get > /dev/null 2>&1; then
  sudo apt-get install -y -qq gnupg
fi

if command -v gpg > /dev/null 2>&1; then
  if [ ! -e "${HOME}/.gnupg/gpg-agent.conf" ]; then
    mkdir -p "${HOME}/.gnupg"
    chmod 700 "${HOME}/.gnupg/"

    ln -s "${HOME}/.gpg-agent.conf" "${HOME}/.gnupg/gpg-agent.conf"
  fi
fi
