#!/usr/bin/env bash

set -e
set -u

echo "--------"
echo "- tmux -"
echo "--------"

if [ `uname` == 'Darwin' ]; then
  brew install \
    tmux \
    reattach-to-user-namespace
elif command -v apt-get > /dev/null 2>&1; then
  sudo apt-get install -y -qq \
    tmux
fi
