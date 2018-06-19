#!/usr/bin/env bash

echo -e "${GREEN}FZF${RESET}"

FZF_INSTALL=`brew --prefix`/opt/fzf/install

if [ `uname` == 'Darwin' ]; then
  brew reinstall fzf fd
else
  if [ ! -d "${HOME}/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ${HOME}/.fzf
    FZF_INSTALL="${HOME}/.fzf/install"
  else
    echo Updating FZF

    cd ${HOME}/.fzf && git pull && ./install
  fi
fi

if [ ! -e "${HOME}/.fzf.bash" ]; then
  FZF_INSTALL
fi
