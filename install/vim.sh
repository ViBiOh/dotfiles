#!/usr/bin/env bash

echo "${GREEN}Vim${RESET}"

if [ ! -e "${HOME}/.vim/autoload/plug.vim" ]; then
  curl -fLo "${HOME}/.vim/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
