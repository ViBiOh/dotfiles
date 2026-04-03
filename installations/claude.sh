#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".claude/CLAUDE.md"
  symlink_home ".claude/settings.json"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink

  rm -rf "${HOME}/.claude"
}

install() {
  symlink

  packages_install "claude-code"
}
