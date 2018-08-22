#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- tmux   -"
echo "----------"

if [ `uname` == 'Darwin' ]; then
  brew reinstall \
    tmux \
    reattach-to-user-namespace
else
  sudo apt-get install -y -qq \
    tmux
fi
