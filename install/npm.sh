#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- NPM    -"
echo "----------"

rm -rf "${HOME}/.npm" "${HOME}/.npm_packages"

if [ `uname` == 'Darwin' ]; then
  brew reinstall node
fi

if command -v npm > /dev/null 2>&1; then
  npm install --ignore-scripts -g npm
fi
