#!/usr/bin/env bash

set -e
set -u

echo "-----------"
echo "- Firefox -"
echo "-----------"

if [ `uname` == 'Darwin' ]; then
  brew cask install firefox
fi
