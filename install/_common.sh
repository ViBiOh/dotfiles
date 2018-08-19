#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- Common -"
echo "----------"

FD_VERSION=7.0.0

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
    openssl \
    fd
else
  sudo apt-get install -y -qq \
    bash \
    bash-completion \
    htop \
    git \
    openssl

  # FD
  architecture=`dpkg --print-architecture`

  set +e
  curl -O https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd_${FD_VERSION}_${architecture}.deb
  set -e

  if [ -e "fd_${FD_VERSION}_${architecture}" ]; then
    sudo dpkg -i fd_${FD_VERSION}_${architecture}.deb
    rm -rf fd_${FD_VERSION}_${architecture}.deb
  fi
fi
