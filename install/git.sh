#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  curl -o "${HOME}/opt/bin/diff-so-fancy" https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
  chmod +x "${HOME}/opt/bin/diff-so-fancy"
}

main
