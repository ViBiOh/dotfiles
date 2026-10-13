#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".pi/agent/auth.json"
  symlink_home ".pi/agent/settings.json"
  symlink_home ".pi/agent/mcp.json"

  symlink_home ".config/AGENTS.md" ".pi/agent/AGENTS.md"
  symlink_home ".config/skills" ".pi/agent/skills"
  symlink_home ".pi/agent/extensions/bash-policy.ts"
  symlink_home ".pi/agent/extensions/mcp-policy.ts"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink

  rm -rf "${HOME}/.pi"
}

install() {
  symlink

  if command -v npm >/dev/null 2>&1; then
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  fi
}
