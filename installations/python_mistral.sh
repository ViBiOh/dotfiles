#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.vibe"
}

install() {
  pip install "mistral-vibe"
}
