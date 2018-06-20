#!/usr/bin/env bash

echo -e "${GREEN}FZF${RESET}"

if [ ! -d "${HOME}/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"
else
  cd "${HOME}/.fzf" && git pull
fi

"${HOME}/.fzf/install" --key-bindings --completion --no-update-rc
