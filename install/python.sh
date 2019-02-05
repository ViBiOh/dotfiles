#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  local PYTHON3_VERSION="3.6.8"

  if [[ ! -d "${HOME}/opt/pyenv" ]]; then
    git clone --depth 1 https://github.com/pyenv/pyenv.git "${HOME}/opt/pyenv"
  else
    pushd "${HOME}/opt/pyenv" && git pull && popd
  fi

  source "${SCRIPT_DIR}/../sources/_python"

  if command -v pyenv 1>/dev/null 2>&1; then
    if command -v apt-get > /dev/null 2>&1; then
      sudo apt-get install -y -qq zlib1g-dev libssl-dev
    fi

    pyenv install "${PYTHON3_VERSION}"
    pyenv global "${PYTHON3_VERSION}"
 
    if command -v pip > /dev/null 2>&1; then
      pip install --user --upgrade pip
    fi
  fi
}

main
