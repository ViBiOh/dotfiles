#!/usr/bin/env bash

set -e
set -u

echo "-------"
echo "- FZF -"
echo "-------"

if ! command -v git > /dev/null 2>&1; then
  exit
fi

if [ ! -d "${HOME}/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"
else
  cd "${HOME}/.fzf" && git pull
fi

"${HOME}/.fzf/install" --key-bindings --completion --no-update-rc
