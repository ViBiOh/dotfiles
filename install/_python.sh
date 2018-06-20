#!/usr/bin/env bash

echo "----------"
echo "- Python -"
echo "----------"

if [ `uname` == 'Darwin' ]; then
  brew reinstall python

  BREW_PREFIX=`brew --prefix`

  unlink ${BREW_PREFIX}/bin/python
  ln -s ${BREW_PREFIX}/bin/python3 ${BREW_PREFIX}/bin/python
  unlink ${BREW_PREFIX}/bin/pip
  ln -s ${BREW_PREFIX}/bin/pip3 /usr/local/bin/pip
else
  sudo apt-get install -y -qq python python-pip
fi

sudo pip install --upgrade pip
