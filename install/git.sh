#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- git    -"
echo "----------"

if [ `uname -s` == 'Darwin' ]; then
  brew install diff-so-fancy
fi
