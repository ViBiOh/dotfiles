#!/usr/bin/env bash

set -e

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks/*; do
  [ -r "${file}" ] && [ -f "${file}" ] && rm -f ${HOME}/.`basename ${file}` && ln -s ${file} ${HOME}/.`basename ${file}`
done

MAX_OS_SSH_CONFIG=""
if [ `uname` == 'Darwin' ]; then
  MAX_OS_SSH_CONFIG="
    UseKeyChain no"
fi

echo "Host *
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    HashKnownHosts yes${MAX_OS_SSH_CONFIG}
    ServerAliveInterval 300
    ServerAliveCountMax 2

Host vibioh
    HostName vibioh.fr
    User vibioh
" >> ${HOME}/.ssh/config


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
    tmux \
    reattach-to-user-namespace \
    pass \
    golang

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
