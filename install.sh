#!/usr/bin/env bash

set -e

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks/*; do
  [ -r "${file}" ] && [ -f "${file}" ] && rm -f ${HOME}/.`basename ${file}` && ln -s ${file} ${HOME}/.`basename ${file}`
done

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


if [ `uname` == 'Darwin' ] && ! command -v brew > /dev/null 2>&1; then
  echo Installing brew
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

  echo
  echo Installing common brew tools
  brew install \
    bash \
    bash-completion \
    fswatch \
    tldr \
    fzf \
    openssl \
    gnupg \
    htop \
    tmux \
    reattach-to-user-namespace \
    pass \
    golang \
    graphviz \
    pgcli

  echo
  echo Installing curl with right option
  brew install curl --with-openssl
  brew link --force curl

  echo
  echo Configuring FZF
  /usr/local/opt/fzf/install

  echo
  echo Follow instruction in README for configuring bash
fi
