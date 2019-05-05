#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if ! command -v perl > /dev/null 2>&1; then
    echo "perl is required"
    exit
  fi

  curl -o "${HOME}/opt/bin/diff-so-fancy" https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
  chmod +x "${HOME}/opt/bin/diff-so-fancy"
}

main
