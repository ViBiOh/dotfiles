#!/usr/bin/env bash

set -e
set -u

echo "--------"
echo "- node -"
echo "--------"

rm -rf "${HOME}/.npm" "${HOME}/.npm_packages" "${HOME}/.babel.json" "${HOME}/.node_repl_history" ${HOME}/.v8flags.*

if ! command -v git > /dev/null 2>&1; then
  exit
fi

if ! command -v make > /dev/null 2>&1; then
  exit
fi

git clone --depth 1 https://github.com/tj/n.git "${HOME}/n"
cd "${HOME}/n"
PREFIX="${HOME}/opt" make install
cd "${HOME}"
rm -rf "${HOME}/n"

source "${HOME}/code/src/github.com/ViBiOh/dotfiles/sources/n"
n latest

if command -v npm > /dev/null 2>&1; then
  npm install --ignore-scripts -g npm npm-check-updates
fi
