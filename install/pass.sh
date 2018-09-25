#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- Pass   -"
echo "----------"

if ! command -v git > /dev/null 2>&1; then
  exit 
fi

if ! command -v make > /dev/null 2>&1; then
  exit 
fi

if command -v brew > /dev/null 2>&1; then
  brew install gnu-getopt tree oath-toolkit
elif command -v apt-get > /dev/null 2>&1; then
  sudo apt-get install -y -qq tree
fi

git clone https://git.zx2c4.com/password-store "${HOME}/password-store"
cd "${HOME}/password-store"
sudo WITH_BASHCOMP=yes WITH_ZSHCOMP=no WITH_FISHCOMP=no PREFIX=/usr/local make install
cd "${HOME}"
rm -rf "${HOME}/password-store"

git clone https://github.com/tadfisher/pass-otp "${HOME}/pass-otp"
cd "${HOME}/pass-otp"
sudo PREFIX=/usr/local make install
cd "${HOME}"
rm -rf "${HOME}/pass-otp"
