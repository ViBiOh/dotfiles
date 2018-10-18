#!/usr/bin/env bash

set -e
set -u

echo "------------"
echo "- Packages -"
echo "------------"

if [ `uname` == 'Darwin' ]; then
  if ! command -v brew > /dev/null 2>&1; then
    mkdir "${HOME}/homebrew" && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "${HOME}/homebrew"
    source "${HOME}/code/src/github.com/ViBiOh/dotfiles/sources/brew"
  fi

  brew update
  brew upgrade
  brew install \
    bash \
    bash-completion \
    htop \
    git \
    fswatch \
    openssl \
    nnn
elif command -v apt-get > /dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get upgrade -y -qq
  sudo apt-get install -y -qq \
    apt-transport-https

  sudo apt-get install -y -qq \
    bash \
    bash-completion \
    htop \
    git \
    openssl

  set +e
  sudo apt-cache show nnn > /dev/null 2>&1
  nnn=$?
  set -e
  if [ "${nnn}" -eq 0 ]; then
    sudo apt-get install -y -qq nnn
  fi
fi
