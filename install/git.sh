#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- git    -"
echo "----------"

if [ `uname -s` == 'Darwin' ]; then
  brew reinstall diff-so-fancy
fi
