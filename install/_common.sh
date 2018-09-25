#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- Common -"
echo "----------"

if [ `uname` == 'Darwin' ]; then
  if ! command -v brew > /dev/null 2>&1; then
    mkdir "~/homebrew" && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "~/homebrew"
    export PATH="$PATH:~/homebrew/sbin:~/homebrew/bin"
  fi

  brew update
  brew reinstall \
    bash \
    bash-completion \
    htop \
    git \
    fswatch \
    openssl
elif command -v apt-get > /dev/null 2>&1; then
  sudo apt-get install -y -qq \
    bash \
    bash-completion \
    htop \
    git \
    openssl
fi
