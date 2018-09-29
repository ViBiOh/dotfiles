#!/usr/bin/env bash

set -e
set -u

echo "-----------"
echo "- Sublime -"
echo "-----------"

if [ `uname` == 'Darwin' ]; then
  brew cask install \
    sublime-text

  ln -f -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /Users/macbook/homebrew/bin
fi
