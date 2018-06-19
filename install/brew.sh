#!/usr/bin/env bash

echo -e "${GREEN}Brew${RESET}"

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
    gnupg
fi
