#!/usr/bin/env bash

echo -e "${GREEN}GPG${RESET}"

if command -v gpg > /dev/null 2>&1; then
  if [ ! -e "${HOME}/.gnupg/gpg-agent.conf" ]; then
    mkdir -p "${HOME}/.gnupg"
    ln -s "${HOME}/.gpg-agent.conf" "${HOME}/.gnupg/gpg-agent.conf"
  fi
fi
