#!/usr/bin/env bash

echo "${GREEN}Pass${RESET}"

if [ `uname` == 'Darwin' ]; then
  brew reinstall pass oath-toolkit zbar

  git clone https://github.com/tadfisher/pass-otp "${HOME}/pass-otp"
  cd "${HOME}/pass-otp"
  make install PREFIX=/usr/local
  rm -rf "${HOME}/pass-otp"
fi
