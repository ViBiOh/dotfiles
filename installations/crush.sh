#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".config/crush/crush.json"
  symlink_home ".config/AGENTS.md"
  symlink_home ".config/go"
  symlink_home ".config/crush/hooks/bash-policy.sh"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink

  rm -rf "${HOME}/.crush"
}

install() {
  symlink

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    brew trust --formula charmbracelet/tap/crush
  fi

  packages_install "charmbracelet/tap/crush"
}
