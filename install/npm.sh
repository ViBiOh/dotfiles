#!/usr/bin/env bash

echo -e "${GREEN}Npm${RESET}"

if [ `uname` == 'Darwin' ]; then
  brew reinstall node
fi

if command -v npm > /dev/null 2>&1; then
  npm install -g npm
fi
