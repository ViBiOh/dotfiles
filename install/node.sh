#!/usr/bin/env bash

set -e
set -u

echo "--------"
echo "- Node -"
echo "--------"

rm -rf "${HOME}/.npm" "${HOME}/.npm_packages"

if [ `uname` == 'Darwin' ]; then
  brew install node
fi

if command -v npm > /dev/null 2>&1; then
  npm install --ignore-scripts -g npm npm-check-updates
fi
