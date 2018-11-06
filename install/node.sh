#!/usr/bin/env bash

set -e
set -u

echo "--------"
echo "- node -"
echo "--------"

rm -rf "${HOME}/.npm" "${HOME}/.npm_packages"

if ! command -v make > /dev/null 2>&1; then
  exit
fi

git clone --depth 1 https://github.com/tj/n.git "${HOME}/n"
cd "${HOME}/n"
sudo PREFIX=/usr/local make install
cd "${HOME}"
rm -rf "${HOME}/n"

source "${HOME}/code/src/github.com/ViBiOh/dotfiles/sources/n"
n latest

if command -v npm > /dev/null 2>&1; then
  npm install --ignore-scripts -g npm npm-check-updates
fi
