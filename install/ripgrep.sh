#!/usr/bin/env bash

set -e
set -u

echo "-----------"
echo "- ripgrep -"
echo "-----------"

if [ `uname -s` == 'Darwin' ]; then
  brew tap burntsushi/ripgrep https://github.com/BurntSushi/ripgrep.git
  brew install ripgrep-bin
elif command -v apt-get > /dev/null 2>&1 && [ `uname -m` == 'x86_64' ]; then
  sudo apt-get install -y -qq ripgrep
fi
