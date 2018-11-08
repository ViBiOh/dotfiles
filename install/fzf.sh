#!/usr/bin/env bash

set -e
set -u

echo "-------"
echo "- FZF -"
echo "-------"

if ! command -v git > /dev/null 2>&1; then
  exit
fi

if [ ! -d "${HOME}/opt/fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/opt/fzf"
else
  cd "${HOME}/opt/fzf" && git pull
fi

"${HOME}/opt/fzf/install" --key-bindings --completion --no-zsh --no-fish --no-update-rc
