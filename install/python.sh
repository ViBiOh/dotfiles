#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if ! command -v git > /dev/null 2>&1; then
    echo "git is required"
    exit
  fi

  if ! command -v make > /dev/null 2>&1; then
    echo "make is required"
    exit
  fi

  if ! command -v gcc > /dev/null 2>&1; then
    echo "gcc is required"
    exit
  fi

  local PYTHON_VERSION="3.7.3"

  if [[ ! -d "${HOME}/opt/pyenv" ]]; then
    git clone --depth 1 https://github.com/pyenv/pyenv.git "${HOME}/opt/pyenv"
  else
    pushd "${HOME}/opt/pyenv" && git pull && popd
  fi

  mkdir -p "${HOME}/opt/python"
  source "${SCRIPT_DIR}/../sources/_python"

  if command -v pyenv 1>/dev/null 2>&1; then
    if [[ "${OSTYPE}" =~ ^darwin ]]; then
      # Zlib header of macOS Mojave
      sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /
    elif command -v apt-get > /dev/null 2>&1; then
      sudo apt-get install -y -qq zlib1g-dev libssl-dev
    fi

    pyenv install -s "${PYTHON_VERSION}"
    pyenv global "${PYTHON_VERSION}"
 
    if command -v pip > /dev/null 2>&1; then
      pip install --user --upgrade pip
    fi
  fi
}

main
