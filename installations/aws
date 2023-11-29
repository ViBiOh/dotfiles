#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.aws"
}

install() {
  packages_install "awscli"

  mkdir -p "${HOME}/.aws"
}
