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
    tmux \
    reattach-to-user-namespace \
    openssl \
    gnupg \
    fd
else
  sudo apt-get install -y -qq \
    bash \
    bash-completion \
    htop \
    git \
    tmux \
    openssl \
    gnupg

  # FD
  curl -O https://github.com/sharkdp/fd/releases/download/v7.0.0/fd_7.0.0_amd64.deb
  sudo dpkg -i fd_7.0.0_amd64.deb
  rm -rf fd_7.0.0_amd64.deb
fi
