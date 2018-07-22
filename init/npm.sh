#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- NPM    -"
echo "----------"

if [ `uname` == 'Darwin' ]; then
  brew reinstall node
fi

if command -v npm > /dev/null 2>&1; then
  npm install -g npm
fi
