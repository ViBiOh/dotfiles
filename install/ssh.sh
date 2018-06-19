#!/usr/bin/env bash

echo -e "${GREEN}SSH${RESET}"

MAC_OS_SSH_CONFIG=""
if [ `uname` == 'Darwin' ]; then
  MAC_OS_SSH_CONFIG="
    UseKeyChain no"
fi

echo "Host *
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    HashKnownHosts yes${MAC_OS_SSH_CONFIG}
    ServerAliveInterval 300
    ServerAliveCountMax 2

Host vibioh
    HostName vibioh.fr
    User vibioh
" > ${HOME}/.ssh/config
