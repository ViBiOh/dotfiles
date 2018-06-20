#!/usr/bin/env bash

echo "----------"
echo "- Pass"
echo "----------"

if [ `uname` == 'Darwin' ]; then
  brew reinstall pass oath-toolkit zbar
else
  sudo apt-get install pass
fi

if command -v git > /dev/null 2>&1; then
  git clone https://github.com/tadfisher/pass-otp "${HOME}/pass-otp"
  cd "${HOME}/pass-otp"
  make install PREFIX=/usr/local
  rm -rf "${HOME}/pass-otp"
fi
