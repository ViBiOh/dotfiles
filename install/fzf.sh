#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.fzf.bash"
  rm -rf "${HOME}/opt/fzf"
}

install() {
  if ! command -v git > /dev/null 2>&1; then
    echo "git not found"
    exit
  fi

  if [[ ! -d "${HOME}/opt/fzf" ]]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/opt/fzf"
  else
    pushd "${HOME}/opt/fzf" && git pull && popd
  fi

  "${HOME}/opt/fzf/install" --key-bindings --completion --no-zsh --no-fish --no-update-rc
}
