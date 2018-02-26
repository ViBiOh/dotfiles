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


if [ `uname` == 'Darwin' ]; then
  if ! command -v brew > /dev/null 2>&1; then
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
      node \
      graphviz \
      jq \
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
  else
    echo
    echo Updating brew packages

    brew update
    brew upgrade
    brew cleanup
  fi
fi

if command -v go > /dev/null 2>&1; then
  echo
  echo Updating golang packages

  go get -u github.com/golang/dep/cmd/dep
  go get -u github.com/golang/lint/golint
  go get -u github.com/google/pprof
  go get -u github.com/kisielk/errcheck
  go get -u github.com/nsf/gocode
  go get -u golang.org/x/tools/cmd/goimports
  go get -u github.com/rakyll/hey
  go get -u github.com/asciimoo/wuzz
fi

if command -v npm > /dev/null 2>&1; then
  echo
  echo Updating npm packages

  npm update -g
fi

