#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- Common -"
echo "----------"

if [ `uname` == 'Darwin' ]; then
  if ! command -v brew > /dev/null 2>&1; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  brew update
  brew reinstall \
    bash \
    bash-completion \
    htop \
    git \
    fswatch \
    openssl
else
  sudo apt-get install -y -qq \
    bash \
    bash-completion \
    htop \
    git \
    openssl
fi
