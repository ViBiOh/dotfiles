#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".claude/CLAUDE.md"
  symlink_home ".claude/settings.json"
  symlink_home ".claude/statusline-command.sh"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink

  rm -rf "${HOME}/.claude"
}

install() {
  symlink

  packages_install_desktop "claude-code"
}
