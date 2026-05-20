#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".config/crush/crush.json"
  symlink_home ".config/agents.md" ".config/crush/AGENTS.md"
  symlink_home ".config/crush/hooks/deny-dangerous.sh"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  packages_install charmbracelet/tap/crush
}
