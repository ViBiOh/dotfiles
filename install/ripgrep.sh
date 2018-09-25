#!/usr/bin/env bash

set -e
set -u

echo "-----------"
echo "- ripgrep -"
echo "-----------"

if [ `uname -s` == 'Darwin' ]; then
  brew install ripgrep
elif command -v apt-get > /dev/null 2>&1; then
  sudo apt-get install ripgrep
fi
