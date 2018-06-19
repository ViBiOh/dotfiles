#!/usr/bin/env bash

echo -e "${GREEN}FZF${RESET}"

if [ `uname` == 'Darwin' ]; then
  brew reinstall fzf fd
  FZF_INSTALL=`brew --prefix`/opt/fzf/install
else
  if [ ! -d "${HOME}/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ${HOME}/.fzf
  else
    cd ${HOME}/.fzf && git pull
  fi
  FZF_INSTALL="${HOME}/.fzf/install"
fi

${FZF_INSTALL} --key-bindings --completion --no-update-rc
