#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".config/AGENTS.md"
  symlink_home ".config/skills" ".claude/skills"

  symlink_home ".claude/CLAUDE.md"
  symlink_home ".claude/settings.json"
  symlink_home ".claude/statusline-command.sh"
  symlink_home ".claude/agents"
  symlink_home ".claude/hooks"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink

  rm -rf "${HOME}/.claude"
}

install() {
  symlink

  if package_exists "claude-code"; then
    packages_install_desktop "claude-code"
  elif command -v apt >/dev/null 2>&1; then
    sudo curl --disable --silent --show-error --location --max-time 30 https://downloads.claude.ai/keys/claude-code.asc -o /etc/apt/keyrings/claude-code.asc
    echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" | sudo tee /etc/apt/sources.list.d/claude-code.list
    sudo apt update
    sudo apt install claude-code
  fi
}
