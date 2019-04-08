#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clean() {
  rm -rf "${HOME}/.gem" \
         "${HOME}/.travis"
}

main() {
  clean

  if command -v gem > /dev/null 2>&1; then
    gem install travis --no-rdoc --no-ri --user-install --bindir "${HOME}/opt/bin"
  fi
}

main
