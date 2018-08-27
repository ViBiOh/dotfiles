#!/usr/bin/env bash

set -e
set -u

echo "-----------"
echo "- ripgrep -"
echo "-----------"

if [ `uname -s` == 'Darwin' ]; then
  brew reinstall ripgrep
else
  sudo apt-get install ripgrep
fi
